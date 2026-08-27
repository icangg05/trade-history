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
 * Login & logout. Pendaftaran mandiri ada di RegisterController, tapi hanya
 * terbuka kalau REGISTER_TOKEN diisi di .env; tanpa itu user dibuat lewat
 * `php artisan db:seed` atau halaman admin.
 */
class LoginController extends Controller
{
    /** Empat percobaan gagal, lalu kunci selama satu menit. */
    private const MAX_ATTEMPTS = 4;

    private const LOCKOUT_SECONDS = 60;

    public function create(): Response
    {
        return Inertia::render('Login', [
            'canRegister' => filled(config('auth.register_token')),
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
        $key = $this->throttleKey($request);

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
        $request->session()->regenerate();

        // Admin tidak punya wilayah trading — langsung ke halaman pengelolaan.
        return redirect()->intended($request->user()->is_admin ? route('admin.index') : route('dashboard'));
    }

    public function destroy(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }

    private function throttleKey(Request $request): string
    {
        return Str::transliterate(Str::lower($request->string('email')).'|'.$request->ip());
    }
}
