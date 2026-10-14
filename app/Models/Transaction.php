<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['account_id', 'type', 'amount', 'rate_idr', 'occurred_at', 'proof_path', 'note', 'transfer_pair_id'])]
class Transaction extends Model
{
    use Concerns\HasHashid;

    protected function casts(): array
    {
        return [
            'occurred_at' => 'date',
            'amount' => 'decimal:2',
            'rate_idr' => 'decimal:3',
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /** Sisi seberang transfer antar akun: deposit untuk withdrawal ini, atau sebaliknya. */
    public function pair(): BelongsTo
    {
        return $this->belongsTo(self::class, 'transfer_pair_id');
    }
}
