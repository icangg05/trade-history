<?php

namespace App\Http\Controllers;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Satu controller melayani dua klien: halaman web (Inertia) dan aplikasi
 * mobile (JSON di bawah /api). Props halaman dikirim apa adanya ke ponsel,
 * jadi tidak ada angka yang dihitung ulang di tempat kedua — saldo, winrate,
 * dan pelanggaran aturan di aplikasi selalu sama persis dengan di browser.
 */
abstract class Controller
{
    /** Halaman web, atau isinya sebagai JSON untuk aplikasi mobile. */
    protected function page(string $component, array $props): Response|JsonResponse
    {
        return request()->isApi()
            ? response()->json($props)
            : Inertia::render($component, $props);
    }

    /**
     * Aksi yang berhasil. Web kembali ke halaman sebelumnya — atau ke `$to` —
     * dengan pesan flash; aplikasi menerima pesan yang sama plus data yang
     * baru lahir, supaya tidak perlu memuat ulang hanya untuk tahu id-nya.
     * `$data` boleh berupa closure: web tidak memakainya, jadi tidak perlu
     * membayar query-nya.
     */
    protected function done(string $message, ?string $to = null, array|Closure $data = [], int $status = 200): RedirectResponse|JsonResponse
    {
        if (request()->isApi()) {
            return response()->json(['message' => $message, ...value($data)], $status);
        }

        return ($to === null ? back() : redirect()->to($to))->with('success', $message);
    }

    /**
     * Aksi yang ditolak karena keadaan data, bukan karena isian form — mis.
     * trade yang mau digabung tidak berurutan. Galat isian tetap lewat
     * ValidationException, yang sudah menjawab 422 sendiri untuk /api.
     */
    protected function failed(string $message, int $status = 422): RedirectResponse|JsonResponse
    {
        return request()->isApi()
            ? response()->json(['message' => $message], $status)
            : back()->with('error', $message);
    }
}
