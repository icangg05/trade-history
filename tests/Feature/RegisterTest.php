<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Pendaftaran mandiri dijaga token dari .env: tanpa token yang cocok tidak ada
 * akun baru, dan tanpa REGISTER_TOKEN sama sekali halamannya tidak ada.
 */
class RegisterTest extends TestCase
{
    use RefreshDatabase;

    private const FORM = [
        'name' => 'Trader Baru',
        'email' => 'baru@contoh.com',
        'password' => 'rahasia-panjang',
        'password_confirmation' => 'rahasia-panjang',
    ];

    public function test_token_yang_cocok_membuat_akun(): void
    {
        config()->set('auth.register_token', 'token-rahasia');

        $this->post('/register', [...self::FORM, 'token' => 'token-rahasia'])
            ->assertRedirect('/accounts');

        $this->assertDatabaseHas('users', ['email' => 'baru@contoh.com', 'is_admin' => false]);
        $this->assertAuthenticated();
    }

    public function test_token_salah_ditolak(): void
    {
        config()->set('auth.register_token', 'token-rahasia');

        $this->post('/register', [...self::FORM, 'token' => 'tebakan'])
            ->assertSessionHasErrors('token');

        $this->assertGuest();
        $this->assertDatabaseCount('users', 0);
    }

    public function test_token_wajib_diisi(): void
    {
        config()->set('auth.register_token', 'token-rahasia');

        $this->post('/register', self::FORM)->assertSessionHasErrors('token');

        $this->assertDatabaseCount('users', 0);
    }

    public function test_tanpa_token_di_env_pendaftaran_tertutup(): void
    {
        config()->set('auth.register_token', null);

        $this->get('/register')->assertNotFound();
        $this->post('/register', [...self::FORM, 'token' => ''])->assertNotFound();

        $this->assertDatabaseCount('users', 0);
    }

    public function test_halaman_login_menyembunyikan_tautan_daftar(): void
    {
        config()->set('auth.register_token', null);
        $this->get('/login')->assertInertia(fn ($page) => $page->where('canRegister', false));

        config()->set('auth.register_token', 'token-rahasia');
        $this->get('/login')->assertInertia(fn ($page) => $page->where('canRegister', true));
    }
}
