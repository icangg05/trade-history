<?php

namespace App\Http\Controllers;

use App\Console\Commands\BackupDatabase;
use App\Models\GeminiKey;
use App\Models\User;
use App\Services\Gemini;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Inertia\Inertia;
use Inertia\Response;
use RuntimeException;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Satu halaman untuk dua hal yang hanya boleh disentuh admin:
 * daftar pengguna, dan kunci-kunci Gemini yang dipakai seluruh aplikasi.
 */
class AdminController extends Controller
{
    public function index(Request $request): Response
    {
        return Inertia::render('Admin', [
            'users' => User::withCount('accounts')
                ->orderBy('name')
                ->get()
                ->map(fn (User $user) => [
                    ...$user->only('id', 'name', 'email', 'is_admin', 'accounts_count'),
                    'created_at' => $user->created_at->toDateString(),
                    'is_self' => $user->id === $request->user()->id,
                ]),
            // Kunci utuh tidak pernah dikirim ke browser — cukup potongannya.
            'geminiKeys' => GeminiKey::query()->orderBy('id')->get()->map(fn (GeminiKey $key) => [
                'id' => $key->id,
                'name' => $key->name,
                'preview' => $key->preview(),
            ]),
            'backups' => BackupDatabase::files(),
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

    public function storeGeminiKey(Request $request): RedirectResponse
    {
        GeminiKey::create($request->validate([
            'name' => ['required', 'string', 'max:60'],
            'api_key' => ['required', 'string', 'max:255'],
        ]));

        return back()->with('success', 'Kunci ditambahkan.');
    }

    public function destroyGeminiKey(GeminiKey $key): RedirectResponse
    {
        $key->delete();

        return back()->with('success', 'Kunci dihapus.');
    }

    /**
     * Panggil Gemini sekali dengan kunci ini; kalimat yang kembali = kunci hidup.
     * JSON, bukan redirect: hasilnya menempel di baris kuncinya sendiri.
     */
    public function testGeminiKey(GeminiKey $key, Gemini $gemini): JsonResponse
    {
        // Sisa jeda dikirim terpisah supaya browser bisa menghitungnya mundur.
        if ($sisa = $key->cooldownLeft()) {
            return response()->json([
                'message' => sprintf('Kunci "%s" baru saja dipakai.', $key->name),
                'retry_after' => $sisa,
            ], 429);
        }

        try {
            return response()->json(['message' => $gemini->ping($key)]);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 502);
        }
    }

    /**
     * Buat cadangan sekarang juga. Berkasnya masuk ke daftar di halaman admin
     * (dipangkas jadi 4 terbaru), diunduh lewat downloadBackup().
     */
    public function backup(): RedirectResponse
    {
        abort_unless(config('database.connections.'.config('database.default'))['driver'] === 'mysql', 422, 'Backup hanya tersedia untuk MySQL.');

        try {
            BackupDatabase::dump();
        } catch (RuntimeException $e) {
            abort(500, $e->getMessage());
        }

        return back()->with('success', 'Cadangan database dibuat.');
    }

    /**
     * Unduh cadangan yang sudah tersimpan. Nama dicocokkan ke pola berkas dump
     * — polanya tidak memuat "/", jadi tidak ada jalan keluar dari direktori.
     */
    public function downloadBackup(string $name): BinaryFileResponse
    {
        abort_unless(preg_match('/^[\w-]+\.sql$/', $name) === 1, 404);

        $path = BackupDatabase::dir().'/'.$name;
        abort_unless(File::exists($path), 404);

        return response()->download($path);
    }

    private function isLastAdmin(User $user): bool
    {
        return $user->is_admin && User::where('is_admin', true)->count() === 1;
    }
}
