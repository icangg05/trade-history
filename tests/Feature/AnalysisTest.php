<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\AiAnalysis;
use App\Models\GeminiKey;
use App\Models\User;
use App\Services\AccountStats;
use App\Support\Period;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Halaman analisa. Dua hal yang gampang salah:
 *   - hasil terakhir menghilang begitu satu trade baru masuk;
 *   - tombol Perbarui diam-diam tidak memanggil AI karena statistiknya sama.
 */
class AnalysisTest extends TestCase
{
    use RefreshDatabase;

    private function account(): Account
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
        ]);

        $this->onAccount($account);

        return $account;
    }

    private function withTrade(Account $account): Account
    {
        $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'pnl' => 50,
            'opened_at' => CarbonImmutable::now()->subDay()->format('Y-m-d H:i'),
            'closed_at' => CarbonImmutable::now()->subDay()->addHour()->format('Y-m-d H:i'),
        ]);

        return $account;
    }

    public function test_analisa_tetap_tampil_dan_ditandai_usang_saat_statistik_berubah(): void
    {
        $account = $this->account();

        AiAnalysis::create([
            'account_id' => $account->id,
            'period_start' => '2026-01-01',
            'period_end' => '2026-01-31',
            'stats_hash' => str_repeat('0', 40), // statistik apa pun sekarang berbeda
            'result_md' => 'Bacaan lama.',
            'model' => 'gemini-uji',
        ]);

        $analysis = $this->api('get', 'analysis')->assertJsonMissingPath('history')->json('analysis');

        $this->assertSame('Bacaan lama.', $analysis['result_md']);
        $this->assertTrue($analysis['stale']);
        $this->assertNotNull($analysis['analyzed_at']);
    }

    public function test_perbarui_tetap_memanggil_ai_walau_statistik_tidak_berubah(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::sequence()
            ->push(['candidates' => [['content' => ['parts' => [['text' => 'Bacaan pertama.']]]]]])
            ->push(['candidates' => [['content' => ['parts' => [['text' => 'Bacaan kedua.']]]]]])]);

        GeminiKey::create(['name' => 'Uji', 'api_key' => 'kunci-uji']);
        $this->withTrade($this->account());

        $this->api('post', 'analysis', ['period' => '30d'])->assertSuccessful();

        // Data sama persis, tombol ditekan lagi setelah jeda pendinginan lewat.
        $this->travel(GeminiKey::COOLDOWN + 1)->seconds();
        $this->api('post', 'analysis', ['period' => '30d'])->assertSuccessful();

        Http::assertSentCount(2);
        $this->api('get', 'analysis')
            ->assertJsonPath('analysis.result_md', 'Bacaan kedua.')
            ->assertJsonPath('analysis.stale', false);
    }

    public function test_klik_kedua_dalam_10_detik_ditolak_tanpa_memanggil_ai(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(
            ['candidates' => [['content' => ['parts' => [['text' => 'Bacaan.']]]]]]
        )]);

        GeminiKey::create(['name' => 'Uji', 'api_key' => 'kunci-uji']);
        $this->withTrade($this->account());

        $this->api('post', 'analysis', ['period' => '30d']);
        // Semua kunci sedang jeda: dijawab 502, sama seperti Gemini yang gagal.
        $this->api('post', 'analysis', ['period' => '30d'])->assertStatus(502);

        Http::assertSentCount(1);
    }

    /**
     * Pola perilaku di balik angka: posisi ke-berapa dalam sehari, masuk lagi
     * tak lama setelah loss, dan lot setelah loss.
     */
    public function test_perilaku_menghitung_overtrading_dan_balas_dendam(): void
    {
        $account = $this->account();
        $day = CarbonImmutable::now()->subDay()->format('Y-m-d');
        $trade = fn (string $open, string $close, float $pnl, float $lot) => $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'buy', 'lot' => $lot,
            'entry_price' => 100, 'sl_price' => 90, 'pnl' => $pnl,
            'opened_at' => "$day $open", 'closed_at' => "$day $close",
        ]);

        $trade('09:00', '09:30', -20, 0.1);
        $trade('09:45', '10:15', -40, 0.3); // 15 menit setelah loss, lot dinaikkan
        $trade('13:00', '13:30', 30, 0.1);
        $trade('14:00', '14:30', 10, 0.1);

        [$from, $to] = Period::resolve($account, '30d');
        $behavior = (new AccountStats($account))->behavior($from, $to);

        $this->assertSame(1, $behavior['by_trade_of_day']['ke-4+']['trades']);
        $this->assertSame(-40.0, $behavior['after_loss']['dibuka ≤60 menit setelah loss']['pnl']);
        // Setelah loss: trade ke-2 (0.3) dan ke-3 (0.1). Setelah win: ke-4 (0.1).
        $this->assertSame(['setelah win' => 0.1, 'setelah loss' => 0.2], $behavior['avg_lot']);
        $this->assertSame(['win' => 30, 'loss' => 30], $behavior['hold_minutes']);
        $this->assertSame(4, $behavior['by_stop']['SL di sisi rugi']['trades']);
    }

    /**
     * AI menerima pembanding, bukan cuma statistik: periode sebelumnya dan
     * rencana dari analisa terakhir untuk dinilai dijalankan atau tidak.
     */
    public function test_analisa_mengirim_periode_sebelumnya_dan_rencana_terakhir(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(
            ['candidates' => [['content' => ['parts' => [['text' => 'Bacaan baru.']]]]]]
        )]);
        GeminiKey::create(['name' => 'Uji', 'api_key' => 'kunci-uji']);

        $account = $this->withTrade($this->account());
        $account->trades()->create([
            'symbol' => 'XAUUSD', 'direction' => 'sell', 'entry_price' => 100, 'sl_price' => 110, 'pnl' => -30,
            'opened_at' => CarbonImmutable::now()->subDays(45)->format('Y-m-d H:i'),
            'closed_at' => CarbonImmutable::now()->subDays(45)->addHour()->format('Y-m-d H:i'),
        ]);

        $plan = AiAnalysis::create([
            'account_id' => $account->id,
            'period_start' => '2026-01-01',
            'period_end' => '2026-01-31',
            'stats_hash' => str_repeat('0', 40),
            'result_md' => "## Ringkasan\nLama.\n\n## Rencana periode berikutnya\n**Fokus utama:** maksimal 2 posisi sehari.\n",
            'model' => 'gemini-uji',
        ]);
        $plan->forceFill(['updated_at' => now()->subDays(3)])->saveQuietly();

        $this->api('post', 'analysis', ['period' => '30d'])->assertSuccessful();

        Http::assertSent(function ($request) {
            $text = $request->data()['contents'][0]['parts'][0]['text'];
            $data = json_decode(substr($text, strpos($text, "DATA:\n") + 6), true);

            $this->assertSame(1, $data['periode_sebelumnya']['total_trades']);
            $this->assertSame(-30.0, (float) $data['periode_sebelumnya']['net_pnl']);
            $this->assertSame('**Fokus utama:** maksimal 2 posisi sehari.', $data['rencana_sebelumnya']['isi']);
            $this->assertArrayHasKey('by_trade_of_day', $data['perilaku']);

            return true;
        });

        // Kartu angka di aplikasi memakai pembanding yang sama.
        $this->api('get', 'analysis', ['period' => '30d'])
            ->assertJsonPath('previous.total_trades', 1);
    }
}
