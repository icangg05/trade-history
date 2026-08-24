<?php

namespace Tests\Feature;

use App\Models\GeminiKey;
use App\Services\Gemini;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

/**
 * Penggiliran kunci: tiap permintaan memakai kunci yang paling lama menganggur,
 * dan sebuah kunci baru boleh dipakai lagi setelah 10 detik.
 */
class GeminiKeyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => 'ok']]]]],
            ]),
        ]);
    }

    public function test_kunci_dipakai_bergantian_lalu_menunggu_pendinginan(): void
    {
        GeminiKey::create(['name' => 'A', 'api_key' => 'kunci-a']);
        GeminiKey::create(['name' => 'B', 'api_key' => 'kunci-b']);

        $gemini = new Gemini;

        $gemini->analyze(['total_trades' => 1]);
        $gemini->analyze(['total_trades' => 1]);

        // Dua permintaan berturut-turut = dua kunci berbeda, bukan kunci yang sama dua kali.
        Http::assertSent(fn ($request) => $request->hasHeader('x-goog-api-key', 'kunci-a'));
        Http::assertSent(fn ($request) => $request->hasHeader('x-goog-api-key', 'kunci-b'));

        try {
            $gemini->analyze(['total_trades' => 1]);
            $this->fail('Permintaan ketiga seharusnya ditolak: semua kunci masih panas.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Tunggu', $e->getMessage());
        }

        Http::assertSentCount(2);

        $this->travel(GeminiKey::COOLDOWN + 1)->seconds();

        $gemini->analyze(['total_trades' => 1]);

        Http::assertSentCount(3);
    }

    public function test_tanpa_kunci_permintaan_ditolak(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/belum ditambahkan/');

        (new Gemini)->analyze(['total_trades' => 1]);
    }
}
