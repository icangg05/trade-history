<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\User;
use App\Services\AccountStats;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Aturan akun: cara batasnya ditulis, dan pelanggaran apa yang muncul dari data
 * yang sudah ada. Tidak ada satu pun yang memblokir input — semuanya penanda.
 */
class RuleLimitTest extends TestCase
{
    use RefreshDatabase;

    public function test_dasar_perkiraan_adalah_modal_ditambah_dana_masuk(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);

        $account->transactions()->createMany([
            ['type' => 'deposit', 'amount' => 500, 'occurred_at' => '2026-01-05'],
            ['type' => 'withdrawal', 'amount' => 200, 'occurred_at' => '2026-01-10'],
        ]);

        // Hasil trading sengaja tidak ikut: dasarnya modal dan arus dana saja.
        $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
            'pnl' => 250, 'opened_at' => '2026-01-06 09:00', 'closed_at' => '2026-01-06 10:00',
        ]);

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $this->assertSame(1300.0, $this->get('/rules')->viewData('page')['props']['basis']);
    }

    public function test_penarikan_dan_setoran_tidak_dihitung_sebagai_drawdown(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'IDR',
            'initial_balance' => 10_000_000,
            'started_at' => '2026-01-01',
        ]);

        // Trading hanya pernah turun 400rb; 7jt yang keluar adalah untung yang
        // ditarik ke rekening bank, bukan kerugian.
        $account->trades()->createMany([
            ['symbol' => 'XAUUSD', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => 2_000_000, 'opened_at' => '2026-02-01 09:00', 'closed_at' => '2026-02-01 10:00'],
            ['symbol' => 'XAUUSD', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => -400_000, 'opened_at' => '2026-03-01 09:00', 'closed_at' => '2026-03-01 10:00'],
        ]);
        $account->transactions()->createMany([
            ['type' => 'withdrawal', 'amount' => 7_000_000, 'occurred_at' => '2026-04-01'],
            ['type' => 'deposit', 'amount' => 3_000_000, 'occurred_at' => '2026-05-01'],
        ]);

        $summary = (new AccountStats($account))->summary(
            CarbonImmutable::parse('2026-01-01'),
            CarbonImmutable::parse('2026-12-31'),
        );

        $this->assertSame(400_000.0, $summary['max_drawdown']['amount']);

        // Persennya diukur dari puncak kurva trading (12jt), bukan saldo berjalan.
        $this->assertSame(3.33, $summary['max_drawdown']['pct']);
    }

    public function test_menarik_untung_tidak_menyalakan_peringatan_batas_rugi(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'IDR',
            'initial_balance' => 10_000_000,
            'started_at' => '2026-01-01',
        ]);
        $account->rule()->create(['max_total_loss_pct' => 10]);

        $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
            'pnl' => 2_000_000, 'opened_at' => '2026-02-01 09:00', 'closed_at' => '2026-02-01 10:00',
        ]);
        // Separuh saldo ditarik keluar: dulu ini terbaca sebagai drawdown 50%.
        $account->transactions()->create(['type' => 'withdrawal', 'amount' => 6_000_000, 'occurred_at' => '2026-04-01']);

        $status = (new AccountStats($account))->ruleStatus(CarbonImmutable::parse('2026-04-02'));

        $this->assertSame(0.0, $status['drawdown_pct']);
        $this->assertFalse($status['drawdown_breached']);
    }

    public function test_batas_harian_tersimpan_dalam_satu_satuan_saja(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $this->put('/rules', ['max_daily_loss_pct' => 2, 'daily_profit_target' => 150])
            ->assertSessionHasNoErrors();

        $rule = $account->refresh()->rule;

        $this->assertNull($rule->max_daily_loss);
        $this->assertSame(2.0, (float) $rule->max_daily_loss_pct);
        $this->assertSame(150.0, (float) $rule->daily_profit_target);
        $this->assertNull($rule->daily_profit_target_pct);

        // Ganti satuan: kolom pasangannya ikut dikosongkan.
        $this->put('/rules', ['max_daily_loss' => 40, 'max_daily_loss_pct' => null])
            ->assertSessionHasNoErrors();

        $rule = $account->refresh()->rule;

        $this->assertSame(40.0, (float) $rule->max_daily_loss);
        $this->assertNull($rule->max_daily_loss_pct);
    }

    public function test_entry_di_luar_sesi_yang_diizinkan_ditandai(): void
    {
        $account = $this->account();
        $account->rule()->create(['allowed_sessions' => ['london']]);

        // Sesi London di WIB: 14:00-23:00.
        $account->trades()->createMany([
            ['symbol' => 'AAA', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => 10, 'opened_at' => '2026-01-05 09:00', 'closed_at' => '2026-01-05 10:00'],
            ['symbol' => 'BBB', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => 10, 'opened_at' => '2026-01-06 15:00', 'closed_at' => '2026-01-06 16:00'],
        ]);

        $violations = $this->violations($account);

        $this->assertSame(['entry di luar sesi yang diizinkan'], $violations['2026-01-05']);
        $this->assertArrayNotHasKey('2026-01-06', $violations);
    }

    public function test_rugi_satu_trade_melewati_batas_risiko_ditandai(): void
    {
        $account = $this->account();                      // modal 1000
        $account->rule()->create(['max_risk_per_trade_pct' => 1]);  // batas 10

        $account->trades()->createMany([
            ['symbol' => 'AAA', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => -25, 'opened_at' => '2026-01-05 15:00', 'closed_at' => '2026-01-05 16:00'],
            ['symbol' => 'BBB', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => -5, 'opened_at' => '2026-01-06 15:00', 'closed_at' => '2026-01-06 16:00'],
            // Untung besar bukan pelanggaran risiko.
            ['symbol' => 'CCC', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
                'pnl' => 300, 'opened_at' => '2026-01-07 15:00', 'closed_at' => '2026-01-07 16:00'],
        ]);

        $violations = $this->violations($account);

        $this->assertSame(['rugi satu trade melewati batas risiko'], $violations['2026-01-05']);
        $this->assertArrayNotHasKey('2026-01-06', $violations);
        $this->assertArrayNotHasKey('2026-01-07', $violations);
    }

    public function test_aturan_yang_tidak_diisi_tidak_menghasilkan_pelanggaran(): void
    {
        $account = $this->account();
        $account->rule()->create(['notes' => 'Jangan entry saat news merah.']);

        $account->trades()->create([
            'symbol' => 'AAA', 'direction' => 'buy', 'entry_price' => 100, 'sl_price' => 90,
            'pnl' => -900, 'opened_at' => '2026-01-05 03:00', 'closed_at' => '2026-01-05 04:00',
        ]);

        $this->assertSame([], $this->violations($account));
    }

    private function account(): Account
    {
        return User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);
    }

    /** @return array<string, list<string>> */
    private function violations(Account $account): array
    {
        return (new AccountStats($account->refresh()))->violations(
            CarbonImmutable::parse('2026-01-01'),
            CarbonImmutable::parse('2026-01-31'),
        );
    }
}
