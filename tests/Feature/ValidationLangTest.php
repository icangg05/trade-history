<?php

namespace Tests\Feature;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Aplikasi berjalan dengan locale `id`, sedangkan framework hanya membawa
 * pesan bahasa Inggris. Tanpa `lang/id/validation.php`, galat isian keluar
 * sebagai kuncinya mentah — "validation.required" — di form web maupun API.
 */
class ValidationLangTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->setLocale('id');
    }

    public function test_setiap_aturan_bawaan_punya_pesan_indonesia(): void
    {
        $english = require base_path('vendor/laravel/framework/src/Illuminate/Translation/lang/en/validation.php');
        $indonesian = require lang_path('id/validation.php');

        unset($english['custom'], $english['attributes']);

        // Aturan yang ditambahkan versi Laravel berikutnya harus ikut
        // diterjemahkan, atau pesannya kembali tampil sebagai kunci.
        foreach ($english as $rule => $message) {
            $this->assertArrayHasKey($rule, $indonesian, "validation.$rule belum diterjemahkan");

            if (is_array($message)) {
                $this->assertSame(array_keys($message), array_keys($indonesian[$rule]), "validation.$rule.*");
            }
        }
    }

    public function test_galat_form_trade_berbahasa_indonesia_dengan_nama_kolom_form(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
        ]);

        $this->onAccount($account)
            ->api('post', 'trades', [
                'symbol' => 'XAUUSD',
                'direction' => 'buy',
                'entry_price' => 100,
                'opened_at' => '2026-02-02 10:00',
                'closed_at' => '2026-02-01 10:00',
            ])
            ->assertJsonValidationErrors([
                'pnl' => 'Hasil wajib diisi.',
                'closed_at' => 'Waktu tutup harus berupa tanggal setelah atau sama dengan waktu buka.',
            ]);
    }

    public function test_api_mengirim_pesan_yang_sama(): void
    {
        $user = User::factory()->create();

        $this->putJson('/api/v1/profile', ['name' => '', 'email' => 'bukan-email'], [
            'Authorization' => 'Bearer '.$user->createToken('uji')->plainTextToken,
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.name.0', 'Nama wajib diisi.')
            ->assertJsonPath('errors.email.0', 'Email harus berupa alamat email yang valid.');
    }
}
