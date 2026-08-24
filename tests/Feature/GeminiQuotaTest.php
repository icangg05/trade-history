<?php

namespace Tests\Feature;

use App\Models\GeminiSetting;
use App\Services\Gemini;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

/**
 * Batas tier gratis Gemini dijaga di sisi kita: permintaan ke-16 dalam satu menit
 * tidak boleh sampai keluar, begitu juga setelah kuota token semenit terpakai.
 */
class GeminiQuotaTest extends TestCase
{
    use RefreshDatabase;

    private GeminiSetting $setting;

    protected function setUp(): void
    {
        parent::setUp();

        $this->setting = GeminiSetting::create(['api_key' => 'kunci-uji', 'model' => 'gemini-3.5-flash']);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => 'ok']]]]],
                'usageMetadata' => ['totalTokenCount' => 1000],
            ]),
        ]);
    }

    public function test_permintaan_berhenti_di_batas_rpm(): void
    {
        // Batas dipatok di sini, bukan diambil dari setelan yang tersimpan —
        // admin boleh menurunkan angkanya kapan saja tanpa membuat test ini merah.
        $this->setting->rpm = 3;

        $gemini = new Gemini($this->setting);

        for ($i = 0; $i < 3; $i++) {
            $gemini->analyze(['total_trades' => 1]);
        }

        Http::assertSentCount(3);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/RPM/');

        $gemini->analyze(['total_trades' => 1]);
    }

    public function test_permintaan_berhenti_saat_token_semenit_habis(): void
    {
        $this->setting->tpm = 2500;

        $gemini = new Gemini($this->setting);

        $gemini->analyze(['total_trades' => 1]);
        $gemini->analyze(['total_trades' => 1]);
        $gemini->analyze(['total_trades' => 1]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/TPM/');

        $gemini->analyze(['total_trades' => 1]);
    }
}
