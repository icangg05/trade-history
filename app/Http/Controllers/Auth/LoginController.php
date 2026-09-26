<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Login & logout versi web, yang hanya untuk admin. Trader masuk dan mendaftar
 * lewat aplikasi mobile (Api\AuthController).
 */
class LoginController extends Controller
{
    /** Empat percobaan gagal, lalu kunci selama satu menit. Berlaku juga di API. */
    public const MAX_ATTEMPTS = 4;

    public const LOCKOUT_SECONDS = 60;

    public const ADMIN_ONLY = 'Versi web hanya untuk admin. Silakan masuk lewat aplikasi mobile.';

    public function create(): Response
    {
        return Inertia::render('Login', [
            // Sisa kunci dititipkan lewat flash saat store() menolak, lalu
            // dihitung mundur di layar. 0 berarti tidak sedang terkunci.
            'lockedFor' => (int) session('lockedFor', 0),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $request->validate(['remember' => ['nullable', 'boolean']]);

        // Kuncinya email+IP, bukan IP saja: penebak kata sandi kehabisan jatah
        // di email yang diincarnya tanpa ikut mengunci orang lain di IP yang
        // sama. Rotasi email dari satu IP masih dibatasi throttle di route.
        $key = self::throttleKey($request);

        if (RateLimiter::tooManyAttempts($key, self::MAX_ATTEMPTS)) {
            event(new Lockout($request));
            $request->session()->flash('lockedFor', RateLimiter::availableIn($key));

            throw ValidationException::withMessages([
                'email' => 'Terlalu banyak percobaan gagal.',
            ]);
        }

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            RateLimiter::hit($key, self::LOCKOUT_SECONDS);

            throw ValidationException::withMessages([
                'email' => 'Email atau kata sandi tidak cocok.',
            ]);
        }

        RateLimiter::clear($key);

        if (! $request->user()->is_admin) {
            Auth::logout();

            throw ValidationException::withMessages(['email' => self::ADMIN_ONLY]);
        }

        $request->session()->regenerate();

        return redirect()->intended(route('admin.index'));
    }

    /**
     * Alamat `/`. Admin ke halamannya; trader yang masih membawa sesi web lama
     * dikeluarkan dan diarahkan ke aplikasi mobile.
     */
    public function home(Request $request): RedirectResponse
    {
        if ($request->user()?->is_admin) {
            return redirect()->route('admin.index');
        }

        if ($request->user()) {
            return $this->destroy($request)->withErrors(['email' => self::ADMIN_ONLY]);
        }

        return redirect()->route('login');
    }

    public function destroy(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }

    public static function throttleKey(Request $request): string
    {
        return Str::transliterate(Str::lower($request->string('email')).'|'.$request->ip());
    }
}
