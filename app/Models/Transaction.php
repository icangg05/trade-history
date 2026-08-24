<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['account_id', 'type', 'amount', 'occurred_at', 'proof_path', 'note'])]
class Transaction extends Model
{
    protected function casts(): array
    {
        return [
            'occurred_at' => 'date',
            'amount' => 'decimal:2',
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /** Efek terhadap saldo: deposit menambah, withdrawal mengurangi. */
    public function signedAmount(): float
    {
        return (float) $this->amount * ($this->type === 'withdrawal' ? -1 : 1);
    }
}
