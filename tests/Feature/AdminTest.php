<?php

namespace Tests\Feature;

use App\Models\GeminiSetting;
use App\Models\User;
use App\Services\Gemini;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Halaman admin: hanya admin yang boleh masuk, admin terakhir tidak bisa
 * dilucuti, dan kunci Gemini di database yang dipakai — bukan yang di .env.
 */
class AdminTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['is_admin' => true]);
    }

    public function test_bukan_admin_tidak_melihat_halaman_admin(): void
    {
        $this->actingAs(User::factory()->create())->get('/admin')->assertNotFound();
    }

    public function test_halaman_admin_terbuka_untuk_admin(): void
    {
        $this->actingAs($this->admin())
            ->get('/admin')
            ->assertOk()
            ->assertInertia(fn ($page) => $page->component('Admin')->has('users', 1)->has('gemini.model'));
    }

    public function test_admin_tidak_bisa_masuk_wilayah_trading(): void
    {
        $admin = $this->admin();

        foreach (['/', '/trades', '/calendar', '/transactions', '/rules', '/analysis', '/accounts'] as $url) {
            $this->actingAs($admin)->get($url)->assertRedirect('/admin');
        }
    }

    public function test_backup_hanya_untuk_admin(): void
    {
        $this->actingAs(User::factory()->create())->get('/admin/backup')->assertNotFound();
    }

    public function test_backup_menolak_koneksi_selain_mysql(): void
    {
        // Test berjalan di sqlite; jalur mysqldump-nya diuji langsung ke kontainer.
        $this->actingAs($this->admin())->get('/admin/backup')->assertStatus(422);
    }

    public function test_admin_bisa_menambah_pengguna(): void
    {
        $this->actingAs($this->admin())
            ->post('/admin/users', [
                'name' => 'Trader Baru',
                'email' => 'baru@contoh.com',
                'password' => 'rahasia-panjang',
                'password_confirmation' => 'rahasia-panjang',
                'is_admin' => false,
            ])
            ->assertRedirect();

        $this->assertDatabaseHas('users', ['email' => 'baru@contoh.com', 'is_admin' => false]);
    }

    public function test_admin_terakhir_tidak_bisa_dilucuti(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->put("/admin/users/{$admin->id}", [
                'name' => $admin->name,
                'email' => $admin->email,
                'is_admin' => false,
            ])
            ->assertSessionHas('error');

        $this->assertTrue($admin->fresh()->is_admin);
    }

    public function test_kunci_dari_database_yang_dipakai_memanggil_gemini(): void
    {
        GeminiSetting::create(['api_key' => 'kunci-dari-database', 'model' => 'gemini-3.5-flash-lite']);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => 'ok']]]]],
            ]),
        ]);

        $gemini = app(Gemini::class);

        $this->assertTrue($gemini->configured());
        $this->assertSame('gemini-3.5-flash-lite', $gemini->model());
        $this->assertSame('kunci-dari-database', $gemini->model() ? GeminiSetting::current()->api_key : null);

        $gemini->analyze(['total_trades' => 1]);

        Http::assertSent(fn ($request) => $request->hasHeader('x-goog-api-key', 'kunci-dari-database')
            && str_contains($request->url(), 'gemini-3.5-flash-lite'));
    }
}
