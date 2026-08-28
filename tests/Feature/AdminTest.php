<?php

namespace Tests\Feature;

use App\Models\GeminiKey;
use App\Models\User;
use App\Services\Gemini;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Halaman admin: hanya admin yang boleh masuk, admin terakhir tidak bisa
 * dilucuti, dan kunci Gemini di database yang dipakai memanggil Gemini.
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
            ->assertInertia(fn ($page) => $page->component('Admin')->has('users', 1)->has('geminiKeys'));
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
        $this->actingAs(User::factory()->create())->post('/admin/backup')->assertNotFound();
    }

    public function test_backup_menolak_koneksi_selain_mysql(): void
    {
        // Test berjalan di sqlite; jalur mysqldump-nya diuji langsung ke kontainer.
        $this->actingAs($this->admin())->post('/admin/backup')->assertStatus(422);
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
        GeminiKey::create(['name' => 'Utama', 'api_key' => 'kunci-dari-database']);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => 'ok']]]]],
            ]),
        ]);

        $gemini = app(Gemini::class);

        $this->assertTrue($gemini->configured());

        $gemini->analyze(['total_trades' => 1]);

        Http::assertSent(fn ($request) => $request->hasHeader('x-goog-api-key', 'kunci-dari-database')
            && str_contains($request->url(), config('services.gemini.model')));
    }

    public function test_admin_menambah_menguji_dan_menghapus_kunci(): void
    {
        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [['content' => ['parts' => [['text' => 'Sabar itu posisi terbaik.']]]]],
            ]),
        ]);

        $admin = $this->admin();

        $this->actingAs($admin)
            ->post('/admin/gemini-keys', ['name' => 'Cadangan', 'api_key' => 'AIza-cadangan'])
            ->assertSessionHas('success');

        $key = GeminiKey::sole();
        $this->assertSame('AIza-cadangan', $key->api_key);

        $this->actingAs($admin)
            ->postJson('/admin/gemini-keys/'.$key->id.'/test')
            ->assertOk()
            ->assertJson(['message' => 'Sabar itu posisi terbaik.']);

        // Tombol Tes tidak boleh jadi pintu belakang: kunci yang sama tetap dingin dulu,
        // dan sisa detiknya dikirim terpisah supaya browser bisa menghitung mundur.
        $this->actingAs($admin)
            ->postJson('/admin/gemini-keys/'.$key->id.'/test')
            ->assertStatus(429)
            ->assertJson(['retry_after' => GeminiKey::COOLDOWN]);

        $this->travel(GeminiKey::COOLDOWN + 1)->seconds();

        $this->actingAs($admin)->postJson('/admin/gemini-keys/'.$key->id.'/test')->assertOk();

        $this->actingAs($admin)->delete('/admin/gemini-keys/'.$key->id)->assertSessionHas('success');

        $this->assertSame(0, GeminiKey::count());
    }
}
