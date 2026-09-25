<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterRequest;
use App\Models\Account;
use App\Models\User;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

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
                    'initial_balance' => (float) $account->initial_balance,
                    // Tanggal polos, bukan serialisasi Carbon: tengah malam WIB
                    // yang diubah ke UTC akan terbaca sebagai hari sebelumnya.
                    'started_at' => $account->started_at->toDateString(),
                ]),
        ]);
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
