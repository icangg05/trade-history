<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['name', 'broker', 'currency', 'initial_balance', 'started_at', 'is_archived'])]
class Account extends Model
{
    protected function casts(): array
    {
        return [
            'started_at' => 'date',
            'initial_balance' => 'decimal:2',
            'is_archived' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function trades(): HasMany
    {
        return $this->hasMany(Trade::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function rule(): HasOne
    {
        return $this->hasOne(AccountRule::class);
    }

    public function analyses(): HasMany
    {
        return $this->hasMany(AiAnalysis::class);
    }
}
