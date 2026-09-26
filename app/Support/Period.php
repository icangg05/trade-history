<?php

namespace App\Support;

use App\Models\Account;
use Carbon\CarbonImmutable;

/**
 * Rentang cepat yang dipakai dashboard dan analisa: 30 hari, 90 hari, setahun,
 * atau seluruh umur akun. Satu tempat, supaya "30 hari" di kedua layar — dan
 * di aplikasi mobile — selalu berarti potongan tanggal yang sama.
 */
class Period
{
    public const DAYS = ['30d' => 30, '90d' => 90, '1y' => 365];

    /**
     * Kunci yang tidak dikenal jatuh ke 30 hari, dan kunci yang dikembalikan
     * ikut dinormalkan supaya tombol aktif di layar cocok dengan datanya.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable, 2: string}
     */
    public static function resolve(Account $account, ?string $key): array
    {
        $to = CarbonImmutable::now()->endOfDay();

        if ($key === 'all') {
            return [CarbonImmutable::parse($account->started_at), $to, 'all'];
        }

        $key = array_key_exists((string) $key, self::DAYS) ? $key : '30d';

        return [$to->subDays(self::DAYS[$key])->startOfDay(), $to, $key];
    }

    /**
     * Rentang sepanjang periode ini, tepat sebelum ia dimulai — pembanding
     * "membaik atau memburuk". Seluruh umur akun tidak punya pembanding.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}|null
     */
    public static function previous(CarbonImmutable $from, string $key): ?array
    {
        if (! array_key_exists($key, self::DAYS)) {
            return null;
        }

        $to = $from->subDay()->endOfDay();

        return [$to->subDays(self::DAYS[$key])->startOfDay(), $to];
    }
}
