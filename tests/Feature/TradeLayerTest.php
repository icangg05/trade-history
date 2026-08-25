<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\Trade;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Satu ide berlapis dicatat sebagai satu trade: entry rata-rata terboboti lot
 * dan lot total. Kalau turunan itu salah, seluruh statistik ikut bohong.
 */
class TradeLayerTest extends TestCase
{
    use RefreshDatabase;

    private function account(): Account
    {
        return User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);
    }

    public function test_entry_dan_lot_diturunkan_dari_layer(): void
    {
        $trade = $this->account()->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 999,   // ditimpa ringkasan layer
            'lot' => 99,
            'entries' => [
                ['price' => 100, 'lot' => 0.1],
                ['price' => 90, 'lot' => 0.1],
                ['price' => 80, 'lot' => 0.2],
            ],
            'sl_price' => 77.5,     // risiko 10 dari entry rata-rata 87,5
            'tp_price' => 117.5,    // imbalan 30
            'opened_at' => '2026-01-02 10:00',
        ]);

        $this->assertSame('87.50000', $trade->entry_price);
        $this->assertSame('0.40', $trade->lot);
        $this->assertSame('3.00', $trade->rr_planned);
        $this->assertSame('open', $trade->status);
    }

    public function test_form_menyimpan_layer_dan_mengabaikan_entry_kiriman(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $this->post('/trades', [
            'symbol' => 'xauusd',
            'direction' => 'buy',
            'entry_price' => 1,
            'lot' => 1,
            'entries' => [
                ['price' => 100, 'lot' => 0.1],
                ['price' => 80, 'lot' => 0.1],
            ],
            'opened_at' => '2026-01-02 10:00',
        ])->assertSessionHasNoErrors();

        $trade = Trade::sole();

        $this->assertSame('90.00000', $trade->entry_price);
        $this->assertSame('0.20', $trade->lot);
        $this->assertCount(2, $trade->entries);
    }

    public function test_menggabungkan_trade_menjadi_satu_trade_berlayer(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $ids = [
            $this->layerTrade($account, 100, 0.1, 50, '10:00')->id,
            $this->layerTrade($account, 90, 0.1, 30, '10:30')->id,
            $this->layerTrade($account, 80, 0.2, -20, '11:00')->id,
        ];

        $this->post('/trades/merge', ['ids' => $ids])
            ->assertSessionHasNoErrors()
            ->assertRedirect('/trades');

        $trade = Trade::sole();

        $this->assertSame('87.50000', $trade->entry_price);  // (10 + 9 + 16) / 0.4
        $this->assertSame('0.40', $trade->lot);
        $this->assertSame('60.00', $trade->pnl);
        $this->assertCount(3, $trade->entries);
        $this->assertSame('2026-01-02 10:00:00', $trade->opened_at->toDateTimeString());
        $this->assertSame('2026-01-02 12:00:00', $trade->closed_at->toDateTimeString());
    }

    public function test_menggabungkan_trade_beda_simbol_ditolak(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $first = $this->layerTrade($account, 100, 0.1, 50, '10:00');
        $second = $this->layerTrade($account, 90, 0.1, 30, '10:30');
        $second->update(['symbol' => 'EURUSD']);

        $this->post('/trades/merge', ['ids' => [$first->id, $second->id]])
            ->assertSessionHas('error');

        $this->assertSame(2, Trade::count());
    }

    public function test_menggabungkan_trade_akun_lain_ditolak(): void
    {
        $mine = $this->account();
        $others = $this->account();
        $this->actingAs($mine->user)->withSession(['current_account_id' => $mine->id]);

        $ids = [
            $this->layerTrade($mine, 100, 0.1, 50, '10:00')->id,
            $this->layerTrade($others, 90, 0.1, 30, '10:30')->id,
        ];

        $this->post('/trades/merge', ['ids' => $ids])->assertSessionHas('error');

        $this->assertSame(2, Trade::count());
    }

    private function layerTrade(Account $account, float $entry, float $lot, float $pnl, string $time): Trade
    {
        return $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => $entry,
            'lot' => $lot,
            'sl_price' => 70,
            'pnl' => $pnl,
            'opened_at' => '2026-01-02 '.$time,
            'closed_at' => '2026-01-02 12:00',
        ]);
    }
}
