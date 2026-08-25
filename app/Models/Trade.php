<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'account_id', 'symbol', 'direction', 'lot',
    'entry_price', 'entries', 'sl_price', 'tp_price', 'exit_price',
    'pnl', 'pips', 'opened_at', 'closed_at',
    'setup', 'tags', 'notes', 'source', 'ai_raw',
])]
class Trade extends Model
{
    protected function casts(): array
    {
        return [
            'opened_at' => 'datetime',
            'closed_at' => 'datetime',
            'lot' => 'decimal:2',
            'entry_price' => 'decimal:5',
            'sl_price' => 'decimal:5',
            'tp_price' => 'decimal:5',
            'exit_price' => 'decimal:5',
            'pnl' => 'decimal:2',
            'pips' => 'decimal:1',
            'rr_planned' => 'decimal:2',
            'rr_realized' => 'decimal:2',
            'tags' => 'array',
            'entries' => 'array',
            'ai_raw' => 'array',
        ];
    }

    /**
     * `entry_price`, `lot`, `status`, `rr_planned` dan `rr_realized` selalu
     * diturunkan dari layer, harga & pnl — dipasang di event `saving` supaya
     * semua jalur simpan (form manual, import AI, seeder, tinker) menghasilkan
     * nilai yang sama.
     */
    protected static function booted(): void
    {
        static::saving(function (Trade $trade) {
            // Ringkasan layer harus lebih dulu: hitungan R di bawah membacanya.
            $trade->summariseEntries();
            $trade->rr_planned = $trade->computeRrPlanned();
            $trade->rr_realized = $trade->computeRrRealized();
            $trade->status = $trade->computeStatus();
        });
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /**
     * Layer entry trade ini. Trade satu layer (termasuk semua data lama) tetap
     * punya satu layer di sini, jadi pemanggilnya tidak perlu bercabang.
     *
     * @return list<array{price: float, lot: float|null}>
     */
    public function layers(): array
    {
        if (! $this->entries) {
            return [['price' => (float) $this->entry_price, 'lot' => $this->lot === null ? null : (float) $this->lot]];
        }

        return array_map(
            fn (array $layer) => ['price' => (float) $layer['price'], 'lot' => (float) $layer['lot']],
            $this->entries,
        );
    }

    /**
     * Entry dan lot yang tersimpan adalah ringkasan layernya: rata-rata harga
     * terboboti lot, dan lot total. Semua hitungan lain (R, statistik, kalender)
     * cukup membaca dua kolom itu dan tidak perlu tahu soal layer.
     */
    private function summariseEntries(): void
    {
        $layers = $this->entries;

        if (! $layers) {
            return;
        }

        $lots = array_sum(array_column($layers, 'lot'));

        if ($lots <= 0) {
            return;
        }

        $weighted = array_sum(array_map(fn (array $l) => $l['price'] * $l['lot'], $layers));

        $this->lot = round($lots, 2);
        $this->entry_price = round($weighted / $lots, 5);
    }

    /**
     * Posisi stop loss terhadap entry. Stop yang sudah digeser ke entry atau
     * melewatinya bukan kesalahan input — itu manajemen risiko biasa.
     */
    public const STOP_RISK = 'risk';           // masih di sisi rugi

    public const STOP_BREAKEVEN = 'breakeven'; // persis di harga entry

    public const STOP_LOCKED = 'locked';       // sudah lewat entry, profit terkunci

    public function stopState(): ?string
    {
        if ($this->entry_price === null || $this->sl_price === null) {
            return null;
        }

        $entry = (float) $this->entry_price;
        $sl = (float) $this->sl_price;

        if ($sl === $entry) {
            return self::STOP_BREAKEVEN;
        }

        // Risiko buy ada di bawah entry, risiko sell di atasnya.
        return ($this->sign() === 1 ? $sl < $entry : $sl > $entry)
            ? self::STOP_RISK
            : self::STOP_LOCKED;
    }

    public function isClosed(): bool
    {
        return $this->pnl !== null;
    }

    /** +1 untuk buy, -1 untuk sell. */
    public function sign(): int
    {
        return $this->direction === 'sell' ? -1 : 1;
    }

    /**
     * Jarak entry ke stop loss — penyebut semua perhitungan R.
     *
     * Hanya stop yang masih di sisi rugi yang punya arti sebagai risiko. Begitu
     * stop digeser ke break-even atau ke sisi profit, risiko awalnya tidak lagi
     * tercatat di mana pun, jadi R memang tidak bisa dihitung — null, bukan angka
     * karangan dari jarak yang sekarang justru mengunci profit.
     */
    private function risk(): ?float
    {
        return $this->stopState() === self::STOP_RISK
            ? abs((float) $this->entry_price - (float) $this->sl_price)
            : null;
    }

    public function computeRrPlanned(): ?float
    {
        $risk = $this->risk();

        if ($risk === null || $this->tp_price === null) {
            return null;
        }

        return round(abs((float) $this->tp_price - (float) $this->entry_price) / $risk, 2);
    }

    public function computeRrRealized(): ?float
    {
        $risk = $this->risk();

        if ($risk === null || $this->exit_price === null) {
            return null;
        }

        $moved = ((float) $this->exit_price - (float) $this->entry_price) * $this->sign();

        return round($moved / $risk, 2);
    }

    public function computeStatus(): string
    {
        if ($this->pnl === null) {
            return 'open';
        }

        return match (true) {
            (float) $this->pnl > 0 => 'win',
            (float) $this->pnl < 0 => 'loss',
            default => 'be',
        };
    }
}
