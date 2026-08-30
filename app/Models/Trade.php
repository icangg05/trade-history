<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'account_id', 'symbol', 'direction', 'lot',
    'entry_price', 'sl_price', 'tp_price', 'exit_price',
    'pnl', 'opened_at', 'closed_at',
    'setup', 'group_id', 'pre_group', 'notes', 'source', 'ai_raw',
])]
class Trade extends Model
{
    use Concerns\HasHashid;

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
            'rr_planned' => 'decimal:2',
            'rr_realized' => 'decimal:2',
            'pre_group' => 'array',
            'ai_raw' => 'array',
        ];
    }

    /**
     * `status`, `rr_planned` dan `rr_realized` selalu diturunkan dari harga &
     * pnl — dipasang di event `saving` supaya semua jalur simpan (form manual,
     * import AI, seeder, tinker) menghasilkan nilai yang sama.
     */
    protected static function booted(): void
    {
        static::saving(function (Trade $trade) {
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
        return match (true) {
            (float) $this->pnl > 0 => 'win',
            (float) $this->pnl < 0 => 'loss',
            default => 'be',
        };
    }
}
