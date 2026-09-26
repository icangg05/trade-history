<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Modal awal dihapus dari aplikasi: saldo akun dimulai dari deposit. Modal yang
 * sudah tercatat dipindah jadi deposit bertanggal paling awal di akunnya, jadi
 * saldo, kurva, dan laporan tidak bergeser. Kolomnya tetap ada, bernilai 0.
 */
return new class extends Migration
{
    private const NOTE = 'Modal awal';

    public function up(): void
    {
        foreach (DB::table('accounts')->where('initial_balance', '>', 0)->get() as $account) {
            $first = collect([
                $account->started_at,
                DB::table('trades')->where('account_id', $account->id)
                    ->selectRaw('MIN(COALESCE(closed_at, opened_at)) as d')->value('d'),
                DB::table('transactions')->where('account_id', $account->id)->min('occurred_at'),
            ])->filter()->map(fn ($date) => substr($date, 0, 10))->min();

            DB::table('transactions')->insert([
                'account_id' => $account->id,
                'type' => 'deposit',
                'amount' => $account->initial_balance,
                'occurred_at' => $first,
                'note' => self::NOTE,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('accounts')->where('id', $account->id)->update(['initial_balance' => 0]);
        }
    }

    public function down(): void
    {
        foreach (DB::table('transactions')->where('note', self::NOTE)->whereNull('proof_path')->get() as $row) {
            DB::table('accounts')->where('id', $row->account_id)->increment('initial_balance', $row->amount);
            DB::table('transactions')->where('id', $row->id)->delete();
        }
    }
};
