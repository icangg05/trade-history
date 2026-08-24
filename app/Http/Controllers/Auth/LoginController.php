<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Aplikasi satu pengguna: hanya login/logout, tidak ada pendaftaran.
 * User pertama dibuat lewat `php artisan db:seed`.
 */
class LoginController extends Controller
{
    public function create(): Response
    {
        return Inertia::render('Login', [
            'canRegister' => filled(config('auth.register_token')),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $request->validate(['remember' => ['nullable', 'boolean']]);

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            throw ValidationException::withMessages([
                'email' => 'Email atau kata sandi tidak cocok.',
            ]);
        }

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
}
