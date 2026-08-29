<?php

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function share(Request $request): array
    {
        $account = $request->currentAccount();

        // Pesan sesaat dikirim lewat kanal flash Inertia, bukan prop biasa: prop
        // ikut tersimpan di state history browser, jadi toast lama tampil lagi
        // setiap kali halaman dipulihkan dengan tombol kembali — termasuk waktu
        // chat AI ditutup. Flash Inertia sengaja tidak ikut disimpan ke history.
        if ($flash = array_filter($request->session()->only(['success', 'error', 'info']))) {
            Inertia::flash($flash);
        }

        return [
            ...parent::share($request),

            'auth' => [
                'user' => $request->user()?->only('id', 'name', 'email', 'is_admin'),
            ],

            'accounts' => fn () => $request->accountList()->map->only('id', 'name', 'broker', 'currency'),

            'currentAccount' => fn () => $account?->only('id', 'name', 'broker', 'currency', 'initial_balance', 'started_at'),

            // Halaman laporan mengunduh PDF lewat form POST biasa, bukan kunjungan
            // Inertia — respons biner tidak bisa ditangani Inertia. Form itu butuh
            // `_token`, dan cookie XSRF-TOKEN sudah terenkripsi jadi tidak terbaca JS.
            'csrf' => fn () => csrf_token(),
        ];
    }
}
