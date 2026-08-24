<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * Seluruh setelan Gemini — kunci, nama model, dan batas kuota — dikelola admin
 * lewat halaman /admin dan hanya hidup di sini. Tidak ada lagi GEMINI_* di .env.
 *
 * Tabelnya sengaja satu baris: ini setelan aplikasi, bukan data per pengguna.
 * Kolom yang kosong jatuh ke nilai bawaan di config/services.php.
 */
#[Fillable(['api_key', 'model', 'rpm', 'tpm', 'rpd'])]
class GeminiSetting extends Model
{
    protected function casts(): array
    {
        return ['api_key' => 'encrypted'];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new self;
    }

    /** Ditampilkan ke admin tanpa membocorkan kunci utuh. */
    public function preview(): ?string
    {
        $key = $this->api_key;

        return blank($key) ? null : mb_substr($key, 0, 6).'…'.mb_substr($key, -4);
    }

    /** @return array{rpm: int, tpm: int, rpd: int} */
    public function limits(): array
    {
        $defaults = config('services.gemini.limits');

        return [
            'rpm' => (int) ($this->rpm ?: $defaults['rpm']),
            'tpm' => (int) ($this->tpm ?: $defaults['tpm']),
            'rpd' => (int) ($this->rpd ?: $defaults['rpd']),
        ];
    }
}
