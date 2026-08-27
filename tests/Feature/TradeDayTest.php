<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Sebuah trade masuk hitungan hari ia ditutup, bukan hari ia dibuka. Yang masih
 * terbuka tetap berdiri di hari pembukaannya.
 */
class TradeDayTest extends TestCase
{
    use RefreshDatabase;

    public function test_trade_dihitung_di_hari_penutupannya_beserta_pl_hariannya(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);

        // Dibuka 2 Januari, ditutup 3 Januari — terhitung di 3 Januari.
        $this->trade($account, '2026-01-02 22:00', '2026-01-03 09:00', 50);
        $this->trade($account, '2026-01-03 10:00', '2026-01-03 11:00', -20);
        $this->trade($account, '2026-01-02 09:00', '2026-01-02 10:00', 15);

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $page = $this->get('/trades')->viewData('page');

        $this->assertSame(['2026-01-02' => 15.0, '2026-01-03' => 30.0], $page['props']['daily']);

        // Urutannya ikut tanggal tutup: dua trade 3 Januari dulu, baru 2 Januari.
        $this->assertSame(
            ['2026-01-03', '2026-01-03', '2026-01-02'],
            array_map(fn (array $t) => substr($t['closed_at'], 0, 10), $page['props']['trades']['data']),
        );
    }

    public function test_filter_posisi_stop_terpisah_dari_status_hasil(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        // Stop masih di sisi rugi, stop persis di entry, lalu stop yang sudah lewat entry.
        $account->trades()->createMany([
            ['symbol' => 'AAA', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90, 'pnl' => 10, 'opened_at' => '2026-01-02 09:00', 'closed_at' => '2026-01-02 10:00'],
            ['symbol' => 'BBB', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 100, 'pnl' => 10, 'opened_at' => '2026-01-02 09:00', 'closed_at' => '2026-01-02 10:00'],
            ['symbol' => 'CCC', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 105, 'pnl' => 10, 'opened_at' => '2026-01-02 09:00', 'closed_at' => '2026-01-02 10:00'],
            ['symbol' => 'DDD', 'direction' => 'sell', 'entry_price' => 100, 'sl_price' => 95, 'pnl' => 10, 'opened_at' => '2026-01-02 09:00', 'closed_at' => '2026-01-02 10:00'],
        ]);

        $symbols = fn (string $query) => array_column(
            $this->get('/trades?'.$query)->viewData('page')['props']['trades']['data'],
            'symbol',
        );

        $this->assertSame(['DDD', 'CCC'], $symbols('stop=sl_plus'));
        $this->assertSame(['BBB'], $symbols('stop=breakeven'));
        $this->assertSame(['AAA'], $symbols('stop=risk'));

        // Sumbunya terpisah: keempatnya sama-sama `win`, dan bisa dipadu.
        $this->assertSame(['DDD', 'CCC', 'BBB', 'AAA'], $symbols('status=win'));
        $this->assertSame(['CCC'], $symbols('status=win&stop=sl_plus&direction=buy'));
    }

    private function trade(Account $account, string $opened, string $closed, float $pnl): void
    {
        $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'pnl' => $pnl,
            'opened_at' => $opened,
            'closed_at' => $closed,
        ]);
    }
}
