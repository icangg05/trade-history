<?php

namespace App\Support;

/**
 * Mata uang akun, dalam dua keluarga: dolar (USD, dan USC — sen dolar, 1/100
 * USD) dan rupiah (IDR, dan IDC — sen rupiah Exness, 1/100 IDR). Kurs selalu
 * dicatat per dolar, jadi hanya keluarga dolar yang butuh kurs untuk sampai
 * ke rupiah.
 *
 * Cerminan `useFormat.ts` di web dan `format.dart` di aplikasi mobile.
 */
class Currency
{
    public const CODES = ['USD', 'USC', 'IDR', 'IDC'];

    /** Akun sen: satu unitnya 1/100 mata uang induknya — 3700 USC = $37. */
    public static function cents(string $currency): int
    {
        return in_array($currency, ['USC', 'IDC'], true) ? 100 : 1;
    }

    /** Akun rupiah (IDR, IDC) tidak butuh kurs — nilainya sudah rupiah. */
    public static function needsRate(string $currency): bool
    {
        return ! in_array($currency, ['IDR', 'IDC'], true);
    }

    /** Nilai rupiah. `$rate` (Rp per dolar) diabaikan untuk akun rupiah. */
    public static function toIdr(float $amount, ?float $rate, string $currency): float
    {
        return $amount / self::cents($currency) * (self::needsRate($currency) ? (float) $rate : 1);
    }

    /**
     * Nominal akun `$from` dalam satuan akun `$to`. Sekeluarga (USC → USD,
     * IDR → IDC) cukup menggeser sennya; lintas keluarga (dolar ↔ rupiah)
     * baru memakai kurs.
     */
    public static function convert(float $amount, string $from, string $to, ?float $rate): float
    {
        $value = $amount / self::cents($from);

        if (self::needsRate($from) !== self::needsRate($to)) {
            $value = self::needsRate($from) ? $value * $rate : $value / $rate;
        }

        return round($value * self::cents($to), 2);
    }

    /** Dolar ↔ rupiah: pindah akun lewat dua keluarga berbeda butuh kurs. */
    public static function crosses(string $from, string $to): bool
    {
        return self::needsRate($from) !== self::needsRate($to);
    }

    /**
     * Kurs (Rp per dolar, tiga desimal) dari dua nominal yang nilainya sama:
     * satu dalam mata uang dolar, satu dalam mata uang rupiah — mis. 1.000 USC
     * yang jadi Rp160.000 berarti kurs 16.000. Null kalau keduanya sekeluarga.
     */
    public static function rate(float $amount, string $currency, float $other, string $otherCurrency): ?float
    {
        if (! self::crosses($currency, $otherCurrency)) {
            return null;
        }

        [$dollar, $rupiah] = self::needsRate($currency)
            ? [$amount / self::cents($currency), $other / self::cents($otherCurrency)]
            : [$other / self::cents($otherCurrency), $amount / self::cents($currency)];

        return round($rupiah / $dollar, 3);
    }
}
