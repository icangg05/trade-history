<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

/**
 * Pintu masuk aplikasi mobile: token mati kalau lama tidak dipakai, perangkat
 * bisa dikeluarkan dari jauh, dan sandi yang berganti lewat jalur mana pun
 * mencabut semua token lama. Lupa sandi memakai kode 4 digit lewat email.
 */
class AccountSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function bearer(string $token): array
    {
        // Guard Sanctum mengingat pengguna antar-permintaan dalam satu test.
        $this->app['auth']->forgetGuards();

        return ['Authorization' => 'Bearer '.$token];
    }

    public function test_token_mati_setelah_30_hari_tidak_dipakai(): void
    {
        $token = User::factory()->create()->createToken('Pixel')->plainTextToken;

        // Dipakai tiap 29 hari: masa berlakunya terus bergeser.
        $this->travel(29)->days();
        $this->getJson('/api/v1/me', $this->bearer($token))->assertOk();
        $this->travel(29)->days();
        $this->getJson('/api/v1/me', $this->bearer($token))->assertOk();

        $this->travel(31)->days();
        $this->getJson('/api/v1/me', $this->bearer($token))->assertUnauthorized();
    }

    public function test_daftar_perangkat_dan_keluarkan_perangkat_lain(): void
    {
        $user = User::factory()->create();
        $pixel = $user->createToken('Pixel')->plainTextToken;
        $tablet = $user->createToken('Tablet')->accessToken;
        $milikOrangLain = User::factory()->create()->createToken('Lain')->accessToken;

        $this->getJson('/api/v1/devices', $this->bearer($pixel))
            ->assertOk()
            ->assertJsonCount(2, 'devices')
            ->assertJsonFragment(['name' => 'Pixel', 'current' => true])
            ->assertJsonFragment(['name' => 'Tablet', 'current' => false]);

        $this->deleteJson("/api/v1/devices/{$milikOrangLain->id}", [], $this->bearer($pixel))->assertNotFound();
        $this->assertModelExists($milikOrangLain);

        $this->deleteJson("/api/v1/devices/{$tablet->id}", [], $this->bearer($pixel))->assertOk();
        $this->assertSame(['Pixel'], $user->tokens()->pluck('name')->all());
    }

    public function test_nama_perangkat_diperbarui_saat_aplikasi_dibuka(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('Android');

        $this->getJson('/api/v1/me', $this->bearer($token->plainTextToken))->assertOk();
        $this->assertSame('Android', $token->accessToken->refresh()->name);

        $this->getJson('/api/v1/me?device_name=Redmi+Note+12+Pro', $this->bearer($token->plainTextToken))->assertOk();
        $this->assertSame('Redmi Note 12 Pro', $token->accessToken->refresh()->name);
    }

    public function test_admin_mereset_sandi_mencabut_semua_token_pengguna(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $user = User::factory()->create();
        $user->createToken('Pixel');

        $data = ['name' => $user->name, 'email' => $user->email, 'is_admin' => false];

        // Tanpa sandi baru, token tetap.
        $this->actingAs($admin)->put("/admin/users/{$user->id}", $data)->assertSessionHasNoErrors();
        $this->assertSame(1, $user->tokens()->count());

        $this->actingAs($admin)->put("/admin/users/{$user->id}", [
            ...$data,
            'password' => 'sandi-baru-panjang',
            'password_confirmation' => 'sandi-baru-panjang',
        ])->assertSessionHasNoErrors();
        $this->assertSame(0, $user->tokens()->count());
    }

    public function test_lupa_sandi_dengan_kode_4_digit(): void
    {
        Notification::fake();

        $user = User::factory()->create(['email' => 'saya@contoh.com']);
        $user->createToken('Ponsel hilang');

        // Email yang tidak terdaftar ditolak di tempat; tidak ada yang dikirim.
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'siapa@contoh.com'])
            ->assertJsonValidationErrors(['email' => 'Email ini belum terdaftar.']);
        Notification::assertNothingSent();

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'saya@contoh.com'])->assertOk();

        $code = null;
        Notification::assertSentTo($user, PasswordResetCode::class, function (PasswordResetCode $n) use (&$code) {
            $code = $n->code;

            return true;
        });
        Notification::assertCount(1);
        $this->assertMatchesRegularExpression('/^\d{4}$/', $code);

        $reset = fn (string $code) => $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'saya@contoh.com',
            'code' => $code,
            'password' => 'sandi-baru-panjang',
            'password_confirmation' => 'sandi-baru-panjang',
        ]);

        $verify = fn (string $code) => $this->postJson('/api/v1/auth/password/verify', ['email' => 'saya@contoh.com', 'code' => $code]);
        $wrong = $code === '0000' ? '0001' : '0000';

        // Verifikasi hanya mengecek: sandi belum berubah, kodenya masih berlaku.
        $verify($wrong)->assertJsonValidationErrorFor('code');
        $verify($code)->assertOk();
        $this->assertFalse(Hash::check('sandi-baru-panjang', $user->fresh()->password));

        $reset($wrong)->assertJsonValidationErrorFor('code');
        $reset($code)->assertOk();

        $this->assertTrue(Hash::check('sandi-baru-panjang', $user->fresh()->password));
        $this->assertSame(0, $user->tokens()->count());

        // Kode sekali pakai.
        $verify($code)->assertJsonValidationErrorFor('code');
        $reset($code)->assertJsonValidationErrorFor('code');
    }

    public function test_lima_kode_salah_mengunci_walau_minta_kode_baru(): void
    {
        Notification::fake();

        $user = User::factory()->create(['email' => 'saya@contoh.com']);
        $reset = fn (string $code) => $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'saya@contoh.com',
            'code' => $code,
            'password' => 'sandi-baru-panjang',
            'password_confirmation' => 'sandi-baru-panjang',
        ]);
        $sentCode = function () use ($user) {
            $code = null;
            Notification::assertSentTo($user, PasswordResetCode::class, function (PasswordResetCode $n) use (&$code) {
                $code = $n->code;

                return true;
            });

            return $code;
        };

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'saya@contoh.com'])->assertOk();
        $wrong = $sentCode() === '0000' ? '0001' : '0000';

        $verify = fn (string $code) => $this->postJson('/api/v1/auth/password/verify', ['email' => 'saya@contoh.com', 'code' => $code]);

        // Tebakan lewat verifikasi maupun ganti sandi masuk hitungan yang sama.
        foreach ([$verify, $verify, $verify, $reset, $reset] as $guess) {
            $guess($wrong)->assertJsonValidationErrorFor('code');
        }

        // Kode baru tidak mengembalikan jatah tebakan.
        $this->travel(2)->minutes();
        Notification::fake();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'saya@contoh.com'])->assertOk();

        $reset($sentCode())->assertJsonValidationErrors(['code' => 'Terlalu banyak kode salah']);
        $this->assertFalse(Hash::check('sandi-baru-panjang', $user->fresh()->password));
    }

    public function test_kode_kedaluwarsa_setelah_15_menit(): void
    {
        Notification::fake();

        $user = User::factory()->create(['email' => 'saya@contoh.com']);
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'saya@contoh.com'])->assertOk();

        $code = null;
        Notification::assertSentTo($user, PasswordResetCode::class, function (PasswordResetCode $n) use (&$code) {
            $code = $n->code;

            return true;
        });

        $this->travel(16)->minutes();

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'saya@contoh.com',
            'code' => $code,
            'password' => 'sandi-baru-panjang',
            'password_confirmation' => 'sandi-baru-panjang',
        ])->assertJsonValidationErrorFor('code');
    }

    public function test_kirim_kode_dibatasi_per_menit(): void
    {
        Notification::fake();

        // Email yang tidak terdaftar ikut dihitung: inilah rem bagi yang
        // mencoba-coba email untuk mencari siapa yang punya akun.
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/password/forgot', ['email' => "orang{$i}@contoh.com"])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'lagi@contoh.com'])->assertTooManyRequests();
    }
}
