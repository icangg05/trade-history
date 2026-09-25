<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Inertia\Response;
use Laravel\Sanctum\PersonalAccessToken;

class ProfileController extends Controller
{
    public function edit(Request $request): Response|JsonResponse
    {
        return $this->page('Profile', [
            'user' => $request->user()->only('id', 'name', 'email'),
            'accountCount' => $request->user()->accounts()->count(),
        ]);
    }

    /**
     * Mengganti sandi atau email berarti mengambil alih pintu masuk akun, jadi
     * sandi sekarang harus dibuktikan dulu — tanpa itu satu sesi yang terlanjur
     * dibajak cukup untuk mengunci pemiliknya sendiri di luar. Ganti nama tidak
     * menyentuh pintu masuk, jadi tidak ikut diminta.
     */
    public function update(Request $request): RedirectResponse|JsonResponse
    {
        $user = $request->user();
        $newPassword = (string) $request->input('password');
        $takesOverLogin = filled($newPassword) || $request->input('email') !== $user->email;

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email,'.$user->id],
            'password' => ['nullable', 'confirmed', Password::min(8)],
            'current_password' => [Rule::requiredIf($takesOverLogin), 'current_password'],
        ]);

        unset($data['current_password']);

        $user->update(array_filter($data, fn ($value) => filled($value)));

        // Sandi berganti → pintu di perangkat lain ikut ditutup, termasuk yang
        // dipakai orang yang membuat penggantian ini perlu: sesi browser lain
        // dan token aplikasi mobile, kecuali yang sedang dipakai sekarang.
        if (filled($newPassword)) {
            $current = $user->currentAccessToken();

            $user->tokens()
                ->when($current instanceof PersonalAccessToken, fn ($q) => $q->whereKeyNot($current->getKey()))
                ->delete();

            if ($request->hasSession()) {
                Auth::logoutOtherDevices($newPassword);
            }
        }

        return $this->done('Profil diperbarui.', data: ['user' => $user->only('id', 'name', 'email')]);
    }

    /**
     * Hapus akun pengguna beserta seluruh akun trading, trade, transaksi, dan
     * aturannya (cascade lewat foreign key). Tidak bisa dibatalkan, jadi minta
     * kata sandi dulu.
     */
    public function destroy(Request $request): RedirectResponse|JsonResponse
    {
        $request->validate(['password' => ['required', 'current_password']]);

        $user = $request->user();

        // Aplikasi mobile: tidak ada sesi yang perlu diakhiri — tokennya ikut
        // terhapus bersama penggunanya (lihat User::booted()).
        if ($request->isApi()) {
            $user->delete();

            return $this->done('Akun dan seluruh datanya sudah dihapus.');
        }

        Auth::logout();
        $user->delete();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')->with('success', 'Akun dan seluruh datanya sudah dihapus.');
    }
}
