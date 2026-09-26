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
        $page = $this->actingAs(User::factory()->create(['is_admin' => true]))
            ->withSession(['success' => 'Tersimpan.'])
            ->get('/admin')
            ->viewData('page');

        $this->assertSame(['success' => 'Tersimpan.'], $page['flash']);
        $this->assertArrayNotHasKey('flash', $page['props']);
    }
}
