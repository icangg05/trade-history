<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\AiAnalysis;
use App\Models\GeminiKey;
use App\Models\User;
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

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

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

        $this->get('/analysis')->assertInertia(fn ($page) => $page
            ->where('analysis.result_md', 'Bacaan lama.')
            ->where('analysis.stale', true)
            ->has('analysis.analyzed_at')
            ->missing('history'));
    }

    public function test_perbarui_tetap_memanggil_ai_walau_statistik_tidak_berubah(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::sequence()
            ->push(['candidates' => [['content' => ['parts' => [['text' => 'Bacaan pertama.']]]]]])
            ->push(['candidates' => [['content' => ['parts' => [['text' => 'Bacaan kedua.']]]]]])]);

        GeminiKey::create(['name' => 'Uji', 'api_key' => 'kunci-uji']);
        $this->withTrade($this->account());

        $this->post('/analysis', ['period' => '30d'])->assertRedirect();

        // Data sama persis, tombol ditekan lagi setelah jeda pendinginan lewat.
        $this->travel(GeminiKey::COOLDOWN + 1)->seconds();
        $this->post('/analysis', ['period' => '30d'])->assertRedirect();

        Http::assertSentCount(2);
        $this->get('/analysis')->assertInertia(fn ($page) => $page
            ->where('analysis.result_md', 'Bacaan kedua.')
            ->where('analysis.stale', false));
    }

    public function test_klik_kedua_dalam_10_detik_ditolak_tanpa_memanggil_ai(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(
            ['candidates' => [['content' => ['parts' => [['text' => 'Bacaan.']]]]]]
        )]);

        GeminiKey::create(['name' => 'Uji', 'api_key' => 'kunci-uji']);
        $this->withTrade($this->account());

        $this->post('/analysis', ['period' => '30d']);
        $this->post('/analysis', ['period' => '30d'])->assertSessionHas('error');

        Http::assertSentCount(1);
    }
}
