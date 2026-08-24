<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'account_id',
    'max_daily_loss', 'max_daily_loss_pct',
    'daily_profit_target', 'daily_profit_target_pct',
    'max_total_loss_pct', 'max_risk_per_trade_pct',
    'max_trades_per_day', 'min_rr', 'allowed_sessions', 'notes',
])]
class AccountRule extends Model
{
    protected $primaryKey = 'account_id';

    public $incrementing = false;

    protected function casts(): array
    {
        return [
            'allowed_sessions' => 'array',
            'max_daily_loss' => 'decimal:2',
            'daily_profit_target' => 'decimal:2',
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /**
     * Batas loss harian dalam nilai mata uang.
     * Kalau diisi dalam persen, dihitung dari saldo yang diberikan.
     */
    public function dailyLossLimit(float $balance): ?float
    {
        if ($this->max_daily_loss !== null) {
            return (float) $this->max_daily_loss;
        }

        return $this->max_daily_loss_pct !== null
            ? $balance * (float) $this->max_daily_loss_pct / 100
            : null;
    }

    public function dailyProfitGoal(float $balance): ?float
    {
        if ($this->daily_profit_target !== null) {
            return (float) $this->daily_profit_target;
        }

        return $this->daily_profit_target_pct !== null
            ? $balance * (float) $this->daily_profit_target_pct / 100
            : null;
    }
}
