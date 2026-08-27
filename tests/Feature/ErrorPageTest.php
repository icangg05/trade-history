<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Galat pun tetap tampil sebagai halaman aplikasi, bukan halaman putih Symfony. */
class ErrorPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_alamat_yang_tidak_ada_menampilkan_halaman_galat_aplikasi(): void
    {
        $response = $this->get('/alamat-yang-tidak-pernah-ada');

        $response->assertStatus(404);

        $page = $response->viewData('page');

        $this->assertSame('Error', $page['component']);
        $this->assertSame(404, $page['props']['status']);
    }

    public function test_halaman_admin_disamarkan_jadi_404_untuk_trader_biasa(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        // Sengaja 404, bukan 403: keberadaan halaman admin tidak perlu bocor.
        $response = $this->actingAs($user)->get('/admin');

        $response->assertStatus(404);
        $this->assertSame('Error', $response->viewData('page')['component']);
    }

    public function test_permintaan_json_tetap_dijawab_json(): void
    {
        $this->getJson('/alamat-yang-tidak-pernah-ada')
            ->assertStatus(404)
            ->assertJsonStructure(['message']);
    }
}
