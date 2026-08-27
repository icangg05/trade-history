<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Penebak kata sandi hanya dapat empat percobaan. Percobaan kelima ditolak
 * walau sandinya benar, dan login yang berhasil mengosongkan hitungannya.
 */
class LoginThrottleTest extends TestCase
{
    use RefreshDatabase;

    private function user(): User
    {
        return User::factory()->create(['email' => 'trader@contoh.com', 'password' => 'sandi-benar']);
    }

    private function salah(): void
    {
        $this->post('/login', ['email' => 'trader@contoh.com', 'password' => 'tebakan'])
            ->assertSessionHasErrors('email');
    }

    public function test_percobaan_kelima_dikunci_walau_sandinya_benar(): void
    {
        $this->user();

        foreach (range(1, 4) as $ignored) {
            $this->salah();
        }

        // lockedFor dipakai halaman login untuk menghitung mundur.
        $this->post('/login', ['email' => 'trader@contoh.com', 'password' => 'sandi-benar'])
            ->assertSessionHasErrors('email')
            ->assertSessionHas('lockedFor', fn (int $detik) => $detik > 0 && $detik <= 60);

        $this->assertGuest();
    }

    public function test_login_berhasil_mengosongkan_hitungan(): void
    {
        $this->user();

        $this->salah();
        $this->salah();

        $this->post('/login', ['email' => 'trader@contoh.com', 'password' => 'sandi-benar'])
            ->assertRedirect();
        $this->assertAuthenticated();

        $this->post('/logout');

        // Hitungan sudah bersih: empat percobaan penuh tersedia lagi.
        foreach (range(1, 4) as $ignored) {
            $this->salah();
        }

        $this->assertGuest();
    }
}
