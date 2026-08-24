<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\GeminiSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Jalur import AI: gambar sembarangan harus ditolak, data setengah jadi harus
 * ditolak, dan gambar yang benar harus menghasilkan field yang lengkap —
 * termasuk waktu tutup, yang dulu selalu kosong.
 */
class TradeImportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        GeminiSetting::create(['api_key' => 'kunci-uji', 'model' => 'gemini-3.5-flash']);
    }

    private function actingOnAccount(): Account
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USC',
            'initial_balance' => 5000,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
        ]);

        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);

        return $account;
    }

    private function fakeGemini(array $payload): void
    {
        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [[
                    'content' => ['parts' => [['text' => json_encode($payload)]]],
                ]],
            ]),
        ]);
    }

    private function upload()
    {
        return UploadedFile::fake()->image('chart.png', 800, 600);
    }

    public function test_gambar_yang_bukan_layar_trading_ditolak(): void
    {
        $this->actingOnAccount();
        $this->fakeGemini(['is_trade_screenshot' => false, 'low_confidence_fields' => []]);

        $this->post('/trades/extract', ['screenshot' => $this->upload()])
            ->assertStatus(422)
            ->assertJsonPath('error', fn (string $error) => str_contains($error, 'bukan screenshot posisi trading'));
    }

    public function test_data_inti_yang_tidak_terbaca_ditolak(): void
    {
        $this->actingOnAccount();
        $this->fakeGemini([
            'is_trade_screenshot' => true,
            'symbol' => 'XAUUSD',
            'direction' => null,          // tidak terbaca
            'entry_price' => null,        // tidak terbaca
            'low_confidence_fields' => ['direction'],
        ]);

        $response = $this->post('/trades/extract', ['screenshot' => $this->upload()]);

        $response->assertStatus(422);
        $this->assertSame(['direction', 'entry_price'], $response->json('missing'));
    }

    public function test_waktu_tutup_terisi_saat_posisi_sudah_punya_hasil(): void
    {
        $this->actingOnAccount();
        $this->fakeGemini([
            'is_trade_screenshot' => true,
            'symbol' => 'xauusd',
            'direction' => 'buy',
            'entry_price' => 2400.5,
            'sl_price' => 2390,
            'tp_price' => 2430,
            'pnl' => 180,
            'opened_at' => '2026-08-20 09:30',
            'closed_at' => null,          // tidak terbaca di gambar
            'low_confidence_fields' => [],
        ]);

        $response = $this->post('/trades/extract', ['screenshot' => $this->upload()]);

        $response->assertOk();
        $this->assertSame('XAUUSD', $response->json('data.symbol'));
        $this->assertSame('2026-08-20T09:30', $response->json('data.opened_at'));
        $this->assertSame('2026-08-20T09:30', $response->json('data.closed_at'));
    }

    public function test_waktu_tutup_dari_gambar_dipakai_apa_adanya(): void
    {
        $this->actingOnAccount();
        $this->fakeGemini([
            'is_trade_screenshot' => true,
            'symbol' => 'EURUSD',
            'direction' => 'sell',
            'entry_price' => 1.0850,
            'pnl' => -95,
            'opened_at' => '2026-08-20 09:30',
            'closed_at' => '2026-08-20 14:05',
            'low_confidence_fields' => [],
        ]);

        $this->post('/trades/extract', ['screenshot' => $this->upload()])
            ->assertOk()
            ->assertJsonPath('data.closed_at', '2026-08-20T14:05');
    }

    public function test_gambar_tidak_ikut_disimpan(): void
    {
        Storage::fake('local');
        $this->actingOnAccount();
        $this->fakeGemini([
            'is_trade_screenshot' => true,
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 2400,
            'low_confidence_fields' => [],
        ]);

        $this->post('/trades/extract', ['screenshot' => $this->upload()])->assertOk();

        $this->assertEmpty(Storage::disk('local')->allFiles());
    }
}
