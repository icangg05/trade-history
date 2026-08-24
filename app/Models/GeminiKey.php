<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use RuntimeException;

/**
 * Kunci API Gemini, boleh lebih dari satu. Pemakaiannya digilir: yang diambil
 * selalu kunci yang paling lama menganggur, dan sebuah kunci baru boleh dipakai
 * lagi setelah COOLDOWN detik. Kalau semua kunci masih panas, permintaan
 * ditolak dengan sisa detik yang harus ditunggu — bukan diantre.
 */
#[Fillable(['name', 'api_key'])]
class GeminiKey extends Model
{
    /** Jeda minimal sebelum satu kunci yang sama boleh dipakai lagi (detik). */
    public const COOLDOWN = 10;

    protected function casts(): array
    {
        return ['api_key' => 'encrypted', 'last_used_at' => 'datetime'];
    }

    /**
     * Ambil kunci berikutnya yang boleh dipakai dan tandai terpakai.
     *
     * ponytail: pemilihan lalu penandaan tanpa kunci baris. Dua permintaan yang
     * benar-benar bersamaan bisa memilih kunci yang sama — paling buruk satu 429
     * dari Google. Bungkus dengan lockForUpdate() kalau trafiknya sudah ramai.
     */
    public static function next(): self
    {
        $key = static::query()
            ->where(fn ($q) => $q->whereNull('last_used_at')->orWhere('last_used_at', '<=', now()->subSeconds(self::COOLDOWN)))
            ->orderBy('last_used_at') // NULL lebih dulu: kunci yang belum pernah dipakai
            ->first();

        if ($key) {
            return $key->claim();
        }

        $oldest = static::query()->orderBy('last_used_at')->first();

        throw new RuntimeException($oldest === null
            ? 'Kunci Gemini belum ditambahkan. Minta admin menambahkannya di halaman Admin.'
            : 'Semua kunci Gemini baru saja dipakai. Tunggu '.max(1, $oldest->cooldownLeft()).' detik lagi.');
    }

    /**
     * Pakai kunci ini — termasuk saat diuji manual dari halaman admin. Jeda
     * pendinginan berlaku sama: kunci yang sama tidak bisa ditembak dua kali
     * dalam 10 detik hanya karena lewat tombol Tes.
     */
    public function claim(): self
    {
        if ($sisa = $this->cooldownLeft()) {
            throw new RuntimeException('Kunci "'.$this->name.'" baru saja dipakai. Tunggu '.$sisa.' detik lagi.');
        }

        $this->forceFill(['last_used_at' => now()])->save();

        return $this;
    }

    /** Sisa detik sebelum kunci ini boleh dipakai lagi; 0 = boleh sekarang. */
    public function cooldownLeft(): int
    {
        if ($this->last_used_at === null) {
            return 0;
        }

        return max(0, $this->last_used_at->copy()->addSeconds(self::COOLDOWN)->timestamp - now()->timestamp);
    }

    /** Ditampilkan ke admin tanpa membocorkan kunci utuh. */
    public function preview(): string
    {
        return mb_substr($this->api_key, 0, 6).'…'.mb_substr($this->api_key, -4);
    }
}
