<?php

namespace App\Support;

use Hashids\Hashids;

/**
 * Id baris disamarkan sebelum keluar dari aplikasi — di URL maupun di props
 * Inertia. Bukan pengaman: kepemilikan tetap dicek di `Route::bind`. Gunanya
 * supaya id berurutan tidak terbaca dari luar, terutama pada tautan bukti yang
 * ikut tercetak di laporan pajak dan berpindah tangan.
 *
 * Garamnya menumpang APP_KEY, jadi tidak ada rahasia baru yang harus dijaga.
 * Konsekuensinya sama dengan URL bertanda tangan: mengganti APP_KEY membuat
 * tautan yang sudah terlanjur tercetak tidak bisa dibuka lagi.
 */
class Hashid
{
    /** Panjang minimum; id kecil tidak boleh jadi hash dua huruf. */
    private const LENGTH = 12;

    private static ?Hashids $codec = null;

    public static function encode(int|string $id): string
    {
        return self::codec()->encode((int) $id);
    }

    /** 0 untuk masukan yang bukan hash kami — id itu tidak pernah ada barisnya. */
    public static function decode(string $hash): int
    {
        return (int) (self::codec()->decode($hash)[0] ?? 0);
    }

    private static function codec(): Hashids
    {
        return self::$codec ??= new Hashids((string) config('app.key'), self::LENGTH);
    }
}
