<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\Trade;
use App\Models\User;
use App\Services\AccountStats;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Menjaga tiga hal yang kalau salah membuat seluruh jurnal bohong:
 * turunan RR/status, perhitungan saldo, dan validasi sisi SL/TP.
 */
class JournalTest extends TestCase
{
    use RefreshDatabase;

    private function account(array $overrides = []): Account
    {
        return User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
            ...$overrides,
        ]);
    }

    public function test_rr_dan_status_diturunkan_saat_menyimpan_posisi_buy(): void
    {
        $trade = $this->account()->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,      // risiko 10
            'tp_price' => 130,     // imbalan 30
            'exit_price' => 120,   // tercapai 20
            'pnl' => 200,
            'opened_at' => '2026-01-02 10:00',
            'closed_at' => '2026-01-02 14:00',
        ]);

        $this->assertSame('3.00', $trade->rr_planned);
        $this->assertSame('2.00', $trade->rr_realized);
        $this->assertSame('win', $trade->status);
    }

    public function test_rr_posisi_sell_dihitung_dengan_arah_terbalik(): void
    {
        $trade = $this->account()->trades()->create([
            'symbol' => 'EURUSD',
            'direction' => 'sell',
            'entry_price' => 100,
            'sl_price' => 110,     // risiko 10
            'tp_price' => 70,      // imbalan 30
            'exit_price' => 110,   // kena stop: −1R
            'pnl' => -100,
            'opened_at' => '2026-01-03 10:00',
            'closed_at' => '2026-01-03 11:00',
        ]);

        $this->assertSame('3.00', $trade->rr_planned);
        $this->assertSame('-1.00', $trade->rr_realized);
        $this->assertSame('loss', $trade->status);
    }

    public function test_trade_tanpa_hasil_dan_waktu_tutup_ditolak(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        // Aplikasi ini mencatat riwayat: posisi yang belum ada hasilnya tidak dicatat.
        $this->post('/trades', [
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'opened_at' => '2026-01-04 09:00',
        ])->assertSessionHasErrors(['pnl', 'closed_at']);

        $this->assertSame(0, Trade::count());
    }

    public function test_saldo_menggabungkan_modal_arus_dana_dan_hasil_trading(): void
    {
        $account = $this->account();

        $account->transactions()->createMany([
            ['type' => 'deposit', 'amount' => 500, 'occurred_at' => '2026-01-05'],
            ['type' => 'withdrawal', 'amount' => 200, 'occurred_at' => '2026-01-10'],
        ]);

        $this->trade($account, '2026-01-06', 300);
        $this->trade($account, '2026-01-12', -150);

        // 1000 + 500 − 200 + 300 − 150
        $this->assertSame(1450.0, (new AccountStats($account))->balance());
    }

    public function test_kurva_ekuitas_menumpuk_kronologis_dari_titik_awal(): void
    {
        $account = $this->account();
        $account->transactions()->create(['type' => 'deposit', 'amount' => 500, 'occurred_at' => '2026-01-05']);
        $this->trade($account, '2026-01-06', 300);

        $curve = (new AccountStats($account))->equityCurve();

        $this->assertSame(
            [['2026-01-01', 1000.0], ['2026-01-05', 1500.0], ['2026-01-06', 1800.0]],
            array_map(fn ($p) => [$p['date'], $p['balance']], $curve),
        );
    }

    public function test_status_aturan_melaporkan_sisa_jatah_loss_harian(): void
    {
        $account = $this->account();
        $account->rule()->create(['max_daily_loss' => 100]);
        $this->trade($account, CarbonImmutable::today()->toDateString(), -60);

        $status = (new AccountStats($account->fresh()))->ruleStatus();

        $this->assertSame(60.0, $status['loss_used']);
        $this->assertSame(100.0, $status['loss_limit']);
        $this->assertFalse($status['loss_breached']);

        $this->trade($account, CarbonImmutable::today()->toDateString(), -50);

        $this->assertTrue((new AccountStats($account->fresh()))->ruleStatus()['loss_breached']);
    }

    public function test_take_profit_di_sisi_yang_salah_ditolak(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $response = $this->post('/trades', [
            'symbol' => 'XAUUSD',
            'direction' => 'sell',
            'entry_price' => 100,
            'tp_price' => 110,   // di atas entry padahal sell
            'opened_at' => '2026-01-02 10:00',
        ]);

        $response->assertSessionHasErrors('tp_price');
        $this->assertSame(0, Trade::count());
    }

    /**
     * Stop yang sudah digeser ke entry atau melewatinya harus tetap bisa dicatat —
     * itu manajemen risiko, bukan salah input. Yang hilang hanyalah nilai R, karena
     * risiko awalnya memang tidak lagi tersimpan di mana pun.
     */
    public function test_stop_loss_di_harga_entry_dicatat_sebagai_break_even(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $this->post('/trades', [
            'symbol' => 'XAUUSD',
            'direction' => 'sell',
            'entry_price' => 100,
            'sl_price' => 100,
            'tp_price' => 90,
            'opened_at' => '2026-01-02 10:00',
            'closed_at' => '2026-01-02 11:00',
            'pnl' => 0,
        ])->assertSessionHasNoErrors();

        $trade = Trade::sole();

        $this->assertSame(Trade::STOP_BREAKEVEN, $trade->stopState());
        $this->assertNull($trade->rr_planned);
        $this->assertNull($trade->rr_realized);
    }

    public function test_stop_loss_yang_sudah_mengunci_profit_dicatat_sebagai_sl_plus(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        // Sell di 100, stop sudah diturunkan ke 95: posisi tidak bisa rugi lagi.
        $this->post('/trades', [
            'symbol' => 'XAUUSD',
            'direction' => 'sell',
            'entry_price' => 100,
            'sl_price' => 95,
            'tp_price' => 90,
            'exit_price' => 92,
            'pnl' => 80,
            'opened_at' => '2026-01-02 10:00',
            'closed_at' => '2026-01-02 12:00',
        ])->assertSessionHasNoErrors();

        $trade = Trade::sole();

        $this->assertSame(Trade::STOP_LOCKED, $trade->stopState());
        $this->assertNull($trade->rr_planned);
        $this->assertNull($trade->rr_realized);
        $this->assertSame('win', $trade->status);
    }

    public function test_stop_loss_di_sisi_rugi_tetap_menghitung_r(): void
    {
        $account = $this->account();

        $trade = $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'sell',
            'entry_price' => 100,
            'sl_price' => 110,
            'tp_price' => 80,
            'exit_price' => 90,
            'pnl' => 100,
            'opened_at' => '2026-01-02 10:00',
            'closed_at' => '2026-01-02 12:00',
        ]);

        $this->assertSame(Trade::STOP_RISK, $trade->stopState());
        $this->assertSame(2.0, (float) $trade->rr_planned);
        $this->assertSame(1.0, (float) $trade->rr_realized);
    }

    public function test_trade_milik_akun_orang_lain_tidak_bisa_dibuka(): void
    {
        $mine = $this->account();
        $theirs = $this->account();
        $trade = $this->trade($theirs, '2026-01-02', 100);

        $this->actingAs($mine->user)
            ->withSession(['current_account_id' => $mine->id])
            ->get("/trades/{$trade->id}/edit")
            ->assertNotFound();
    }

    public function test_deposit_wajib_menyertakan_bukti(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $this->post('/transactions', [
            'type' => 'deposit',
            'amount' => 500,
            'occurred_at' => '2026-01-05',
        ])->assertSessionHasErrors(['proof', 'rate_idr']);

        $this->assertSame(0, $account->transactions()->count());

        Storage::fake('local');

        $this->post('/transactions', [
            'type' => 'deposit',
            'amount' => 500,
            'rate_idr' => 16250,
            'occurred_at' => '2026-01-05',
            'proof' => UploadedFile::fake()->image('bukti.jpg'),
        ])->assertSessionHasNoErrors();

        $this->assertNotNull($account->transactions()->sole()->proof_path);
    }

    public function test_withdrawal_tidak_menggeser_dasar_persentase_dashboard(): void
    {
        CarbonImmutable::setTestNow('2026-08-20');

        $account = $this->account(['initial_balance' => 10_000, 'started_at' => '2025-01-01']);
        $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'buy', 'status' => 'win',
            'entry_price' => 100, 'exit_price' => 110, 'pnl' => 1_000,
            'opened_at' => '2026-08-10 09:00', 'closed_at' => '2026-08-10 12:00',
        ]);
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $base = fn () => $this->get('/')->viewData('page')['props']['monthlyBase'];

        // Jendela 12 bulan mulai September 2025, jadi dasarnya modal awal.
        $this->assertSame(10_000.0, $base());

        // Menarik dana sekarang tidak boleh menyentuh dasar itu — hasil trading
        // tidak berubah, jadi persentasenya juga tidak boleh berubah.
        $account->transactions()->create([
            'type' => 'withdrawal', 'amount' => 8_000, 'occurred_at' => '2026-08-15',
        ]);

        $this->assertSame(10_000.0, $base());
    }

    public function test_filter_periode_membatasi_daftar_dan_total_dana(): void
    {
        $account = $this->account();
        $account->transactions()->createMany([
            ['type' => 'deposit', 'amount' => 500, 'occurred_at' => '2026-01-05'],
            ['type' => 'deposit', 'amount' => 300, 'occurred_at' => '2026-08-10'],
            ['type' => 'withdrawal', 'amount' => 200, 'occurred_at' => '2025-08-10'],
        ]);
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $totals = fn (array $query) => $this->get('/transactions?'.http_build_query($query))
            ->viewData('page')['props']['totals'];

        // Tanpa parameter: bulan berjalan, bukan seluruh riwayat.
        CarbonImmutable::setTestNow('2026-08-20');
        $this->assertSame(300.0, $totals([])['deposit']);

        $all = $totals(['year' => 'all']);
        $this->assertSame(800.0, $all['deposit']);
        $this->assertSame(200.0, $all['withdrawal']);

        $year = $totals(['year' => 2026, 'month' => 'all']);
        $this->assertSame(800.0, $year['deposit']);
        $this->assertSame(0.0, $year['withdrawal']);

        $this->assertSame(300.0, $totals(['year' => 2026, 'month' => 8])['deposit']);

        // "Semua tahun" ikut mengunci bulannya — Agustus 2025 tidak boleh hilang
        // kalau filter bulannya bocor lintas tahun.
        $this->assertSame(200.0, $totals(['year' => 'all', 'month' => 8])['withdrawal']);
    }

    public function test_kurs_rupiah_tidak_diminta_untuk_akun_rupiah(): void
    {
        $account = $this->account(['currency' => 'IDR']);
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        Storage::fake('local');

        $this->post('/transactions', [
            'type' => 'deposit',
            'amount' => 5_000_000,
            'occurred_at' => '2026-01-05',
            'proof' => UploadedFile::fake()->image('bukti.jpg'),
        ])->assertSessionHasNoErrors();

        $this->assertNull($account->transactions()->sole()->rate_idr);
    }

    public function test_jejak_bacaan_ai_ikut_tersimpan(): void
    {
        $account = $this->account();
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        $raw = ['is_trade_screenshot' => true, 'symbol' => 'XAUUSD', 'low_confidence_fields' => ['lot']];

        $this->post('/trades', [
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 4402.285,
            'sl_price' => 4392.765,
            'opened_at' => '2026-01-02 10:00',
            'closed_at' => '2026-01-02 11:00',
            'pnl' => 12.5,
            'source' => 'ai',
            'ai_raw' => $raw,
        ])->assertSessionHasNoErrors();

        $trade = Trade::sole();

        // Gambarnya tidak disimpan, jadi ini satu-satunya jejak yang tersisa.
        $this->assertSame('ai', $trade->source);
        $this->assertSame($raw, $trade->ai_raw);
    }

    public function test_mata_uang_akun_dibatasi_tiga_pilihan(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user);

        $this->post('/accounts', [
            'name' => 'Salah',
            'currency' => 'EUR',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ])->assertSessionHasErrors('currency');

        foreach (['USD', 'USC', 'IDR'] as $currency) {
            $this->post('/accounts', [
                'name' => 'Akun '.$currency,
                'currency' => $currency,
                'initial_balance' => 5000,
                'started_at' => '2026-01-01',
            ])->assertSessionHasNoErrors();
        }

        $this->assertSame(3, $user->accounts()->count());
    }

    public function test_pnl_bulanan_memisahkan_profit_dan_loss_kotor(): void
    {
        $account = $this->account();
        $today = CarbonImmutable::today()->toDateString();

        $this->trade($account, $today, 300);
        $this->trade($account, $today, -150);
        $this->trade($account, $today, 50);

        $months = (new AccountStats($account))->monthlyPnl();
        $month = end($months);

        // Bersih 200, tapi kotornya tetap terpisah: +350 dan −150.
        $this->assertSame(
            ['pnl' => 200.0, 'profit' => 350.0, 'loss' => -150.0],
            ['pnl' => $month['pnl'], 'profit' => $month['profit'], 'loss' => $month['loss']],
        );
    }

    private function trade(Account $account, string $date, float $pnl): Trade
    {
        return $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'pnl' => $pnl,
            'opened_at' => $date.' 10:00',
            'closed_at' => $date.' 12:00',
        ]);
    }
}
