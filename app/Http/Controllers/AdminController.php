<?php

namespace App\Http\Controllers;

use App\Models\GeminiSetting;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Process;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Inertia\Inertia;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Satu halaman untuk dua hal yang hanya boleh disentuh admin:
 * daftar pengguna, dan kunci Gemini yang dipakai seluruh aplikasi.
 */
class AdminController extends Controller
{
    public function index(Request $request): Response
    {
        $setting = GeminiSetting::current();

        return Inertia::render('Admin', [
            'users' => User::withCount('accounts')
                ->orderBy('name')
                ->get()
                ->map(fn (User $user) => [
                    ...$user->only('id', 'name', 'email', 'is_admin', 'accounts_count'),
                    'created_at' => $user->created_at->toDateString(),
                    'is_self' => $user->id === $request->user()->id,
                ]),
            'gemini' => [
                // Kunci utuh tidak pernah dikirim ke browser — cukup potongannya.
                'key_preview' => $setting->preview(),
                'model' => $setting->model ?: config('services.gemini.model'),
                ...$setting->limits(),
            ],
        ]);
    }

    public function storeUser(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'is_admin' => ['boolean'],
        ]);

        User::create($data);

        return back()->with('success', 'Pengguna ditambahkan.');
    }

    public function updateUser(Request $request, User $user): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['nullable', 'confirmed', Password::min(8)],
            'is_admin' => ['boolean'],
        ]);

        // Admin terakhir tidak boleh melepas statusnya sendiri — kalau tidak,
        // halaman ini jadi tidak bisa dibuka siapa pun lagi.
        if (! ($data['is_admin'] ?? false) && $this->isLastAdmin($user)) {
            return back()->with('error', 'Ini satu-satunya admin. Angkat admin lain dulu.');
        }

        $user->update(array_filter($data, fn ($value, $key) => $key === 'is_admin' || filled($value), ARRAY_FILTER_USE_BOTH));

        return back()->with('success', 'Pengguna diperbarui.');
    }

    public function destroyUser(Request $request, User $user): RedirectResponse
    {
        if ($user->id === $request->user()->id) {
            return back()->with('error', 'Hapus akun sendiri lewat halaman Profil.');
        }

        if ($this->isLastAdmin($user)) {
            return back()->with('error', 'Ini satu-satunya admin. Angkat admin lain dulu.');
        }

        $user->delete();

        return back()->with('success', 'Pengguna beserta seluruh datanya dihapus.');
    }

    public function updateGemini(Request $request): RedirectResponse
    {
        $data = $request->validate([
            // Dikosongkan = kunci lama dipertahankan; tidak ada cara "tidak sengaja" menghapusnya.
            'api_key' => ['nullable', 'string', 'max:255'],
            'model' => ['required', 'string', 'max:60'],
            'rpm' => ['required', 'integer', 'min:1', 'max:10000'],
            'tpm' => ['required', 'integer', 'min:1000'],
            'rpd' => ['required', 'integer', 'min:1'],
        ]);

        $setting = GeminiSetting::current();
        $setting->fill(array_diff_key($data, ['api_key' => null]));

        if (filled($data['api_key'])) {
            $setting->api_key = trim($data['api_key']);
        }

        $setting->save();

        return back()->with('success', 'Setelan Gemini disimpan.');
    }

    public function forgetGeminiKey(): RedirectResponse
    {
        GeminiSetting::current()->fill(['api_key' => null])->save();

        return back()->with('success', 'Kunci dihapus. Aplikasi kembali memakai GEMINI_API_KEY di .env.');
    }

    /**
     * Cadangan database sebagai berkas .sql yang langsung diunduh.
     *
     * ponytail: dump ditampung di memori dulu. Cukup untuk jurnal satu tim;
     * kalau databasenya sudah ratusan MB, pipe langsung ke output.
     */
    public function backup(): StreamedResponse
    {
        $db = config('database.connections.'.config('database.default'));

        abort_unless($db['driver'] === 'mysql', 422, 'Backup hanya tersedia untuk MySQL.');

        // Kata sandi lewat environment, bukan argumen — argumen terbaca di daftar proses.
        $dump = Process::env(['MYSQL_PWD' => $db['password']])
            ->timeout(300)
            ->run([
                'mysqldump',
                '--host='.$db['host'],
                '--port='.$db['port'],
                '--user='.$db['username'],
                '--single-transaction',
                '--quick',
                // Tanpa --set-gtid-purged: klien di image ini mariadb-dump,
                // yang tidak mengenal opsi khusus MySQL itu.
                '--no-tablespaces',
                // MySQL memakai sertifikat bikinan sendiri dan hanya bisa dihubungi
                // dari jaringan compose, jadi verifikasi sertifikatnya dilewati.
                '--ssl-verify-server-cert=0',
                $db['database'],
            ]);

        abort_if($dump->failed(), 500, 'mysqldump gagal: '.$dump->errorOutput());

        $name = $db['database'].'-'.now()->format('Y-m-d-His').'.sql';

        return response()->streamDownload(fn () => print $dump->output(), $name, [
            'Content-Type' => 'application/sql',
        ]);
    }

    private function isLastAdmin(User $user): bool
    {
        return $user->is_admin && User::where('is_admin', true)->count() === 1;
    }
}
