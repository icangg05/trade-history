<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterRequest;
use App\Models\Account;
use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Pintu masuk aplikasi mobile. Browser memakai sesi (LoginController); ponsel
 * menerima satu token Sanctum per perangkat, dikirim di header Authorization.
 *
 * Penjaganya sama dengan halaman login: empat percobaan gagal per email+IP lalu
 * terkunci semenit, plus throttle di rute. Admin tidak diberi token — perannya
 * mengelola pengguna dan kunci Gemini di /admin, bukan mencatat trade.
 */
class AuthController extends Controller
{
    /**
     * Empat digit cuma 10.000 kemungkinan, jadi penjaganya ketat: kode mati
     * setelah 15 menit, dan satu email hanya boleh salah menebak lima kali per
     * jam — meminta kode baru tidak mengembalikan jatah itu.
     */
    private const CODE_MINUTES = 15;

    private const CODE_ATTEMPTS = 5;

    /** Yang perlu diketahui layar login sebelum ada token. */
    public function options(): JsonResponse
    {
        return response()->json([
            'app_name' => config('app.name'),
            'can_register' => filled(config('auth.register_token')),
        ]);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $request->validate(['device_name' => ['nullable', 'string', 'max:100']]);

        $key = LoginController::throttleKey($request);

        if (RateLimiter::tooManyAttempts($key, LoginController::MAX_ATTEMPTS)) {
            event(new Lockout($request));

            throw ValidationException::withMessages([
                'email' => 'Terlalu banyak percobaan gagal. Coba lagi dalam '.RateLimiter::availableIn($key).' detik.',
            ]);
        }

        // validate(), bukan attempt(): tidak ada sesi yang perlu dibuka di sini.
        if (! Auth::validate($credentials)) {
            RateLimiter::hit($key, LoginController::LOCKOUT_SECONDS);

            throw ValidationException::withMessages([
                'email' => 'Email atau kata sandi tidak cocok.',
            ]);
        }

        RateLimiter::clear($key);

        /** @var User $user */
        $user = Auth::getProvider()->retrieveByCredentials($credentials);

        if ($user->is_admin) {
            throw ValidationException::withMessages([
                'email' => 'Akun admin dikelola lewat web, bukan aplikasi mobile.',
            ]);
        }

        return $this->issue($user, $request);
    }

    public function register(RegisterRequest $request): JsonResponse
    {
        return $this->issue(User::create($request->account()), $request, 201);
    }

    /** Keluar dari perangkat ini saja; perangkat lain tetap masuk. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Kamu sudah keluar.']);
    }

    /** Pengguna yang memegang token ini, plus akun trading yang bisa dibuka. */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'user' => [...$user->only('id', 'name', 'email'), 'avatar' => $user->avatarVersion()],
            // Sama dengan pengalih akun di header web: yang diarsipkan tidak ikut.
            'accounts' => $user->accounts()->where('is_archived', false)->orderBy('name')->get()
                ->map(fn (Account $account) => [
                    ...$account->only('id', 'name', 'broker', 'currency'),
                    // Tanggal polos, bukan serialisasi Carbon: tengah malam WIB
                    // yang diubah ke UTC akan terbaca sebagai hari sebelumnya.
                    'started_at' => $account->started_at->toDateString(),
                ]),
        ]);
    }

    /** Perangkat yang sedang masuk ke akun ini — satu token per perangkat. */
    public function devices(Request $request): JsonResponse
    {
        $current = $request->user()->currentAccessToken();

        return response()->json([
            'devices' => $request->user()->tokens()
                ->orderByRaw('coalesce(last_used_at, created_at) desc')
                ->get()
                ->map(fn (PersonalAccessToken $token) => [
                    'id' => $token->id,
                    'name' => $token->name,
                    'created_at' => $token->created_at,
                    'last_used_at' => $token->last_used_at ?? $token->created_at,
                    'current' => $token->is($current),
                ]),
        ]);
    }

    /** Cabut token satu perangkat. Lewat tokens(): hanya milik pengguna ini. */
    public function destroyDevice(Request $request, int $device): JsonResponse
    {
        abort_unless($request->user()->tokens()->whereKey($device)->delete(), 404);

        return response()->json(['message' => 'Perangkat dikeluarkan.']);
    }

    /**
     * Kirim kode reset ke email. Email yang tidak terdaftar langsung ditolak,
     * supaya salah ketik ketahuan di sini, bukan setelah menunggu email yang
     * tidak pernah datang. Harganya: layar ini bisa dipakai mengecek email mana
     * yang punya akun — throttle 5 per menit di rutenya yang memperlambatnya.
     * Emailnya dikirim setelah jawaban keluar, jadi layar tidak menunggu SMTP.
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $user = User::where('email', $request->validate(['email' => ['required', 'email']])['email'])->first();

        if (! $user) {
            throw ValidationException::withMessages(['email' => 'Email ini belum terdaftar.']);
        }

        $sentAt = DB::table('password_reset_tokens')->where('email', $user->email)->value('created_at');

        // Satu kode per menit per email, supaya tombol "kirim ulang" tidak
        // bisa dipakai membanjiri kotak masuk orang.
        if (! ($sentAt && Carbon::parse($sentAt)->gt(now()->subMinute()))) {
            $code = str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);

            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $user->email],
                ['token' => Hash::make($code), 'created_at' => now()],
            );

            defer(fn () => $user->notify(new PasswordResetCode($code, self::CODE_MINUTES)));
        }

        return response()->json([
            'message' => 'Kode 4 digit sudah dikirim ke email kamu. Berlaku '.self::CODE_MINUTES.' menit.',
        ]);
    }

    /** Cek kode saja, sebelum aplikasi menampilkan form sandi baru. Kodenya tidak terpakai. */
    public function verifyResetCode(Request $request): JsonResponse
    {
        $this->resetCodeOwner($request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:4'],
        ]));

        return response()->json(['message' => 'Kode benar.']);
    }

    /**
     * Kode benar → sandi diganti, dan semua token lama ikut dicabut (User::booted()).
     * Kodenya dicek ulang: langkah verifikasi hanya urutan layar di aplikasi.
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:4'],
            'password' => ['required', 'confirmed', Password::min(8)],
        ]);

        $user = $this->resetCodeOwner($data);

        DB::table('password_reset_tokens')->where('email', $user->email)->delete();
        RateLimiter::clear('reset-code:'.$user->email);
        $user->update(['password' => $data['password']]);

        return response()->json(['message' => 'Kata sandi diganti. Semua perangkat lain sudah dikeluarkan.']);
    }

    /**
     * Pemilik kode reset, kalau kodenya benar. Tebakan salah dihitung per
     * email, dari langkah verifikasi maupun ganti sandi.
     *
     * @param  array{email: string, code: string}  $data
     */
    private function resetCodeOwner(array $data): User
    {
        $user = User::where('email', $data['email'])->first();
        $row = $user ? DB::table('password_reset_tokens')->where('email', $user->email)->first() : null;
        $key = 'reset-code:'.$user?->email;

        $valid = $row
            && Carbon::parse($row->created_at)->gt(now()->subMinutes(self::CODE_MINUTES))
            && ! RateLimiter::tooManyAttempts($key, self::CODE_ATTEMPTS)
            && Hash::check($data['code'], $row->token);

        if (! $valid) {
            if ($row) {
                RateLimiter::hit($key, 3600);
            }

            throw ValidationException::withMessages([
                'code' => RateLimiter::tooManyAttempts($key, self::CODE_ATTEMPTS)
                    ? 'Terlalu banyak kode salah. Coba lagi dalam '.ceil(RateLimiter::availableIn($key) / 60).' menit.'
                    : 'Kode salah atau sudah kedaluwarsa.',
            ]);
        }

        return $user;
    }

    private function issue(User $user, Request $request, int $status = 200): JsonResponse
    {
        $device = $request->string('device_name')->trim()->toString() ?: 'Aplikasi mobile';

        return response()->json([
            'token' => $user->createToken($device)->plainTextToken,
            'user' => $user->only('id', 'name', 'email'),
        ], $status);
    }
}
