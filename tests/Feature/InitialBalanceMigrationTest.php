<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\AccountStats;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Modal awal lama pindah jadi deposit tanpa menggeser saldo, dan bisa dibalik. */
class InitialBalanceMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_modal_awal_jadi_deposit_tanggal_paling_awal(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Lama', 'currency' => 'USD', 'initial_balance' => 1000, 'started_at' => '2026-03-01',
        ]);
        // Trade tercatat sebelum tanggal mulai akun: deposit harus mendahuluinya.
        $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
            'pnl' => 50, 'opened_at' => '2026-02-10 09:00', 'closed_at' => '2026-02-10 10:00',
        ]);

        $migration = require database_path('migrations/2026_09_26_000019_move_initial_balance_to_deposit.php');
        $migration->up();

        $account->refresh();
        $deposit = $account->transactions()->sole();

        $this->assertSame(0.0, (float) $account->initial_balance);
        $this->assertSame('deposit', $deposit->type);
        $this->assertSame('2026-02-10', $deposit->occurred_at->toDateString());
        $this->assertSame(1050.0, (new AccountStats($account))->balance());

        $migration->down();

        $this->assertSame(1000.0, (float) $account->refresh()->initial_balance);
        $this->assertSame(0, $account->transactions()->count());
    }
}
