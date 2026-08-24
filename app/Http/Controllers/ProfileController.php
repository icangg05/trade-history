<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rules\Password;
use Inertia\Inertia;
use Inertia\Response;

class ProfileController extends Controller
{
    public function edit(Request $request): Response
    {
        return Inertia::render('Profile', [
            'accountCount' => $request->user()->accounts()->count(),
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email,'.$request->user()->id],
            'password' => ['nullable', 'confirmed', Password::min(8)],
        ]);

        $request->user()->update(array_filter($data, fn ($value) => filled($value)));

        return back()->with('success', 'Profil diperbarui.');
    }

    /**
     * Hapus akun pengguna beserta seluruh akun trading, trade, transaksi, dan
     * aturannya (cascade lewat foreign key). Tidak bisa dibatalkan, jadi minta
     * kata sandi dulu.
     */
    public function destroy(Request $request): RedirectResponse
    {
        $request->validate(['password' => ['required', 'current_password']]);

        $user = $request->user();

        Auth::logout();
        $user->delete();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')->with('success', 'Akun dan seluruh datanya sudah dihapus.');
    }
}
