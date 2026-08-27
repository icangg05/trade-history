<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Mengganti sandi atau email berarti mengganti pintu masuk akun, jadi sandi
 * sekarang harus dibuktikan dulu. Mengganti nama tidak.
 */
class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_ganti_sandi_tanpa_sandi_sekarang_ditolak(): void
    {
        $user = User::factory()->create(['password' => 'rahasia-lama']);

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'email' => $user->email,
                'password' => 'rahasia-baru',
                'password_confirmation' => 'rahasia-baru',
            ])
            ->assertSessionHasErrors('current_password');

        $this->assertTrue(Hash::check('rahasia-lama', $user->refresh()->password));
    }

    public function test_ganti_email_tanpa_sandi_sekarang_ditolak(): void
    {
        $user = User::factory()->create(['password' => 'rahasia-lama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => $user->name, 'email' => 'baru@contoh.test'])
            ->assertSessionHasErrors('current_password');

        $this->assertNotSame('baru@contoh.test', $user->refresh()->email);
    }

    public function test_dengan_sandi_sekarang_penggantian_berhasil(): void
    {
        $user = User::factory()->create(['password' => 'rahasia-lama']);

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'email' => 'baru@contoh.test',
                'password' => 'rahasia-baru',
                'password_confirmation' => 'rahasia-baru',
                'current_password' => 'rahasia-lama',
            ])
            ->assertSessionHasNoErrors();

        $user->refresh();

        $this->assertSame('baru@contoh.test', $user->email);
        $this->assertTrue(Hash::check('rahasia-baru', $user->password));
    }

    public function test_ganti_nama_saja_tidak_minta_sandi(): void
    {
        $user = User::factory()->create(['password' => 'rahasia-lama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Nama Baru', 'email' => $user->email])
            ->assertSessionHasNoErrors();

        $this->assertSame('Nama Baru', $user->refresh()->name);
    }
}
