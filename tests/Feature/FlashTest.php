<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Pesan sesaat harus lewat kanal flash Inertia, bukan prop biasa: prop ikut
 * tersimpan di state history browser, jadi toast lama tampil lagi setiap kali
 * halaman dipulihkan dengan tombol kembali — persis yang terjadi waktu chat AI
 * ditutup, karena tutupnya memang mundur lewat history.
 */
class FlashTest extends TestCase
{
    use RefreshDatabase;

    public function test_pesan_sesaat_dikirim_di_luar_props(): void
    {
        $account = User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);

        $page = $this->actingAs($account->user)
            ->withSession(['current_account_id' => $account->id, 'success' => 'Tersimpan.'])
            ->get('/rules')
            ->viewData('page');

        $this->assertSame(['success' => 'Tersimpan.'], $page['flash']);
        $this->assertArrayNotHasKey('flash', $page['props']);
    }
}
