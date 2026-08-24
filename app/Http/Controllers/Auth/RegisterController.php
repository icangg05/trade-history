<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

class RegisterController extends Controller
{
    public function create(): Response
    {
        abort_if($this->closed(), 404);

        return Inertia::render('Register');
    }

    public function store(Request $request): RedirectResponse
    {
        abort_if($this->closed(), 404);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'token' => ['required', 'string'],
        ]);

        // Dibandingkan dengan hash_equals: waktu bandingnya tetap sama berapa pun
        // karakter yang benar, jadi token tidak bisa ditebak sepotong demi sepotong.
        if (! hash_equals((string) config('auth.register_token'), $data['token'])) {
            throw ValidationException::withMessages(['token' => 'Token pendaftaran tidak cocok.']);
        }

        unset($data['token']);

        Auth::login(User::create($data));
        $request->session()->regenerate();

        return redirect()->route('accounts.index')
            ->with('success', 'Akun dibuat. Sekarang buat akun trading pertamamu.');
    }

    /** Tanpa REGISTER_TOKEN di .env, pendaftaran mandiri tidak dibuka. */
    private function closed(): bool
    {
        return blank(config('auth.register_token'));
    }
}
