<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * API aplikasi mobile. Yang dijaga: token hanya untuk trader, akun di alamat
 * benar-benar milik pemegang token, baris akun lain tidak bisa disentuh lewat
 * alamat akun sendiri, dan angka yang sampai ke ponsel sama persis dengan yang
 * tampil di browser — controllernya memang sama.
 */
class ApiTest extends TestCase
{
    use RefreshDatabase;

    private function account(?User $user = null, array $overrides = []): Account
    {
        return ($user ?? User::factory()->create())->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
            ...$overrides,
        ]);
    }

    private function trade(Account $account, array $overrides = [])
    {
        return $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'pnl' => 50,
            'opened_at' => CarbonImmutable::now()->subDay()->format('Y-m-d H:i'),
            'closed_at' => CarbonImmutable::now()->subDay()->addHour()->format('Y-m-d H:i'),
            ...$overrides,
        ]);
    }

    private function token(User $user): array
    {
        return ['Authorization' => 'Bearer '.$user->createToken('uji')->plainTextToken];
    }

    public function test_login_memberi_token_yang_membuka_api(): void
    {
        $user = User::factory()->create(['email' => 'saya@contoh.com']);
        $this->account($user);

        $token = $this->postJson('/api/v1/auth/login', [
            'email' => 'saya@contoh.com',
            'password' => 'password',
            'device_name' => 'Pixel',
        ])->assertOk()->assertJsonPath('user.email', 'saya@contoh.com')->json('token');

        $this->getJson('/api/v1/me', ['Authorization' => 'Bearer '.$token])
            ->assertOk()
            ->assertJsonPath('accounts.0.name', 'Uji')
            ->assertJsonPath('accounts.0.started_at', '2026-01-01');

        $this->assertSame('Pixel', $user->tokens()->first()->name);
    }

    public function test_sandi_salah_dan_tanpa_token_ditolak(): void
    {
        User::factory()->create(['email' => 'saya@contoh.com']);

        $this->postJson('/api/v1/auth/login', ['email' => 'saya@contoh.com', 'password' => 'salah'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_admin_tidak_diberi_token(): void
    {
        User::factory()->create(['email' => 'admin@contoh.com', 'is_admin' => true]);

        $this->postJson('/api/v1/auth/login', ['email' => 'admin@contoh.com', 'password' => 'password'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_pendaftaran_lewat_api_tetap_butuh_token_pendaftaran(): void
    {
        config(['auth.register_token' => 'rahasia']);

        $form = ['name' => 'Baru', 'email' => 'baru@contoh.com', 'password' => 'sandi-baru-123', 'password_confirmation' => 'sandi-baru-123'];

        $this->getJson('/api/v1/auth/options')->assertJsonPath('can_register', true);

        $this->postJson('/api/v1/auth/register', [...$form, 'token' => 'tebakan'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('token');

        $this->postJson('/api/v1/auth/register', [...$form, 'token' => 'rahasia'])
            ->assertCreated()
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);

        config(['auth.register_token' => null]);

        $this->postJson('/api/v1/auth/register', [...$form, 'email' => 'lain@contoh.com', 'token' => ''])->assertNotFound();
    }

    public function test_angka_dashboard_sama_dengan_halaman_web(): void
    {
        $account = $this->account();
        $this->trade($account);
        $this->trade($account, ['pnl' => -20]);

        $api = $this->getJson("/api/v1/accounts/{$account->id}/dashboard?range=90d", $this->token($account->user))
            ->assertOk()
            ->assertJsonPath('range', '90d')
            ->json();

        $web = $this->actingAs($account->user)
            ->withSession(['current_account_id' => $account->id])
            ->get('/?range=90d')
            ->viewData('page')['props'];

        $this->assertEquals($web['summary'], $api['summary']);
        $this->assertEquals($web['ruleStatus'], $api['ruleStatus']);
        $this->assertSame(30.0, (float) $api['summary']['net_pnl']);
    }

    public function test_akun_orang_lain_dan_akun_arsip_tidak_bisa_dibuka(): void
    {
        $saya = $this->account();
        $orangLain = $this->account();
        $arsip = $this->account($saya->user, ['name' => 'Lama', 'is_archived' => true]);
        $headers = $this->token($saya->user);

        $this->getJson("/api/v1/accounts/{$orangLain->id}/dashboard", $headers)->assertNotFound();
        $this->getJson("/api/v1/accounts/{$arsip->id}/trades", $headers)->assertNotFound();
        $this->getJson("/api/v1/accounts/{$saya->id}/trades", $headers)->assertOk();
    }

    public function test_trade_akun_lain_milik_sendiri_tidak_bisa_diubah_lewat_alamat_akun_ini(): void
    {
        $utama = $this->account();
        $kedua = $this->account($utama->user, ['name' => 'Kedua']);
        $trade = $this->trade($kedua);
        $headers = $this->token($utama->user);

        $this->deleteJson("/api/v1/accounts/{$utama->id}/trades/{$trade->getRouteKey()}", [], $headers)->assertNotFound();
        $this->assertModelExists($trade);

        $this->deleteJson("/api/v1/accounts/{$kedua->id}/trades/{$trade->getRouteKey()}", [], $headers)
            ->assertOk()
            ->assertJsonPath('message', 'Trade dihapus.');
        $this->assertModelMissing($trade);
    }

    public function test_trade_dicatat_dan_diubah_lewat_validasi_yang_sama(): void
    {
        $account = $this->account();
        $headers = $this->token($account->user);
        $url = "/api/v1/accounts/{$account->id}/trades";

        $form = [
            'symbol' => 'xauusd',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'tp_price' => 130,
            'pnl' => 75,
            'opened_at' => '2026-02-02T09:00',
            'closed_at' => '2026-02-02T11:00',
        ];

        // TP di bawah entry untuk posisi buy: ditolak persis seperti di web.
        $this->postJson($url, [...$form, 'tp_price' => 80], $headers)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('tp_price');

        $trade = $this->postJson($url, $form, $headers)
            ->assertCreated()
            ->assertJsonPath('trade.symbol', 'XAUUSD')
            ->assertJsonPath('trade.status', 'win')
            ->json('trade');

        $this->assertEquals(3.0, $trade['rr_planned']);
        $this->assertStringNotContainsString((string) $account->trades()->first()->id, $trade['id']);

        $this->putJson("{$url}/{$trade['id']}", [...$form, 'pnl' => -40], $headers)
            ->assertOk()
            ->assertJsonPath('trade.status', 'loss');

        $this->getJson("{$url}/{$trade['id']}", $headers)
            ->assertOk()
            ->assertJsonPath('trade.pnl', -40);
    }

    public function test_grouping_yang_ditolak_menjawab_422_dengan_alasannya(): void
    {
        $account = $this->account();
        $first = $this->trade($account, ['opened_at' => '2026-01-02 09:00', 'closed_at' => '2026-01-02 09:30']);
        $this->trade($account, ['opened_at' => '2026-01-02 10:00', 'closed_at' => '2026-01-02 10:30']);
        $third = $this->trade($account, ['opened_at' => '2026-01-02 11:00', 'closed_at' => '2026-01-02 11:30']);

        $this->postJson("/api/v1/accounts/{$account->id}/trades/group", [
            'ids' => [$first->getRouteKey(), $third->getRouteKey()],
        ], $this->token($account->user))
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Hanya trade yang berurutan yang bisa digabung jadi satu grup.');
    }

    public function test_transaksi_dengan_bukti_lewat_api(): void
    {
        Storage::fake('local');

        $account = $this->account();
        $headers = $this->token($account->user);
        $url = "/api/v1/accounts/{$account->id}/transactions";

        $id = $this->post($url, [
            'type' => 'deposit',
            'amount' => 500,
            'rate_idr' => 16000,
            'occurred_at' => '2026-02-01',
            'proof' => UploadedFile::fake()->image('bukti.jpg'),
        ], [...$headers, 'Accept' => 'application/json'])->assertCreated()->json('id');

        $this->getJson($url.'?year=2026&month=2', $headers)
            ->assertOk()
            ->assertJsonPath('items.data.0.id', $id)
            ->assertJsonPath('items.data.0.has_proof', true)
            ->assertJsonPath('totals.balance', 1500);

        $this->get("{$url}/{$id}/proof", $headers)->assertOk();
    }

    public function test_keluar_hanya_mencabut_token_perangkat_ini(): void
    {
        $user = User::factory()->create();
        $ponsel = $user->createToken('ponsel')->plainTextToken;
        $tablet = $user->createToken('tablet')->plainTextToken;

        $this->postJson('/api/v1/auth/logout', [], ['Authorization' => 'Bearer '.$ponsel])->assertOk();

        $this->assertSame(['tablet'], $user->tokens()->pluck('name')->all());

        // Guard menyimpan pengguna selama satu proses uji; dilupakan supaya
        // token berikutnya benar-benar diperiksa ulang.
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/me', ['Authorization' => 'Bearer '.$tablet])->assertOk();
    }

    public function test_ganti_sandi_mencabut_token_perangkat_lain(): void
    {
        $user = User::factory()->create();
        $user->createToken('perangkat-lain');
        $headers = $this->token($user);

        $this->putJson('/api/v1/profile', [
            'name' => $user->name,
            'email' => $user->email,
            'password' => 'sandi-baru-123',
            'password_confirmation' => 'sandi-baru-123',
            'current_password' => 'password',
        ], $headers)->assertOk();

        $this->assertSame(['uji'], $user->tokens()->pluck('name')->all());
    }

    public function test_hapus_pengguna_ikut_membuang_tokennya(): void
    {
        $user = User::factory()->create();
        $headers = $this->token($user);

        $this->deleteJson('/api/v1/profile', ['password' => 'salah'], $headers)->assertUnprocessable();

        $this->deleteJson('/api/v1/profile', ['password' => 'password'], $headers)->assertOk();

        $this->assertModelMissing($user);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
