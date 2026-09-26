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
 * alamat akun sendiri.
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

        $this->postJson('/api/v1/auth/register', $form)->assertJsonValidationErrors('token');

        $this->postJson('/api/v1/auth/register', [...$form, 'token' => 'tebakan'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('token');

        $this->postJson('/api/v1/auth/register', [...$form, 'token' => 'rahasia'])
            ->assertCreated()
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);

        config(['auth.register_token' => null]);

        $this->postJson('/api/v1/auth/register', [...$form, 'email' => 'lain@contoh.com', 'token' => ''])->assertNotFound();
    }

    public function test_dashboard_lewat_api(): void
    {
        $account = $this->account();
        $this->trade($account);
        $this->trade($account, ['pnl' => -20]);

        $api = $this->getJson("/api/v1/accounts/{$account->id}/dashboard?range=90d", $this->token($account->user))
            ->assertOk()
            ->assertJsonPath('range', '90d')
            ->json();

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

    public function test_gambar_unggahan_dinormalkan_jadi_jpeg_berukuran_wajar(): void
    {
        Storage::fake('local');

        $account = $this->account();
        $headers = [...$this->token($account->user), 'Accept' => 'application/json'];
        $url = "/api/v1/accounts/{$account->id}/transactions";
        $fields = ['type' => 'deposit', 'amount' => 500, 'rate_idr' => 16000, 'occurred_at' => '2026-02-01'];

        $this->post($url, [...$fields, 'proof' => UploadedFile::fake()->image('mutasi.png', 3000, 1500)], $headers)
            ->assertCreated();

        $proof = Storage::disk('local')->get($account->transactions()->sole()->proof_path);
        [$width, $height, $type] = getimagesizefromstring($proof);
        $this->assertSame([2000, 1000, IMAGETYPE_JPEG], [$width, $height, $type]);

        $this->post('/api/v1/profile/avatar', ['avatar' => UploadedFile::fake()->image('a.png', 1000, 800)], $headers)
            ->assertOk();
        [$width, $height] = getimagesizefromstring(Storage::disk('local')->get($account->user->fresh()->avatar_path));
        $this->assertSame([512, 410], [$width, $height]);

        // Header PNG yang mengaku 10000 × 10000: ditolak dari dimensinya saja,
        // sebelum GD sempat membongkarnya ke memori.
        $giant = "\x89PNG\r\n\x1a\n".pack('N', 13).'IHDR'.pack('NN', 10000, 10000)."\x08\x02\x00\x00\x00".pack('N', 0);

        $this->post($url, [...$fields, 'proof' => UploadedFile::fake()->createWithContent('raksasa.png', $giant)], $headers)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['proof' => 'megapiksel']);
    }

    public function test_withdrawal_tidak_boleh_melebihi_saldo(): void
    {
        Storage::fake('local');

        $account = $this->account(); // modal 1000, tanpa trade
        $headers = [...$this->token($account->user), 'Accept' => 'application/json'];
        $url = "/api/v1/accounts/{$account->id}/transactions";
        $withdraw = fn (float $amount) => [
            'type' => 'withdrawal',
            'amount' => $amount,
            'rate_idr' => 16000,
            'occurred_at' => '2026-02-01',
            'proof' => UploadedFile::fake()->image('bukti.jpg'),
        ];

        $this->post($url, $withdraw(1000.01), $headers)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['amount' => '1.000,00 USD']);

        $id = $this->post($url, $withdraw(1000), $headers)->assertCreated()->json('id');

        // Saldo kini nol, tapi baris ini sendiri tidak ikut dihitung saat diubah:
        // menurunkan jumlahnya boleh, menaikkannya melewati modal tidak.
        $this->post("{$url}/{$id}", [...$withdraw(900), 'proof' => null], $headers)->assertOk();
        $this->post("{$url}/{$id}", [...$withdraw(1200), 'proof' => null], $headers)
            ->assertJsonValidationErrors('amount');
    }

    public function test_gambar_kecil_tidak_membengkak_dan_metadatanya_dibuang(): void
    {
        Storage::fake('local');

        $account = $this->account();
        $headers = [...$this->token($account->user), 'Accept' => 'application/json'];

        // JPEG kualitas rendah berisi kotak acak: dikodekan ulang di kualitas 85
        // pasti lebih besar dari aslinya. EXIF berisi "lokasi" diselipkan tepat
        // setelah penanda awal.
        $image = imagecreatetruecolor(400, 300);
        mt_srand(7);
        for ($x = 0; $x < 400; $x += 4) {
            for ($y = 0; $y < 300; $y += 4) {
                imagefilledrectangle($image, $x, $y, $x + 3, $y + 3, mt_rand(0, 0xFFFFFF));
            }
        }
        ob_start();
        imagejpeg($image, null, 40);
        $exif = "Exif\0\0GPS-rahasia";
        $jpeg = "\xFF\xD8\xFF\xE1".pack('n', strlen($exif) + 2).$exif.substr(ob_get_clean(), 2);

        $this->post("/api/v1/accounts/{$account->id}/transactions", [
            'type' => 'deposit',
            'amount' => 500,
            'rate_idr' => 16000,
            'occurred_at' => '2026-02-01',
            'proof' => UploadedFile::fake()->createWithContent('bukti.jpg', $jpeg),
        ], $headers)->assertCreated();

        $stored = Storage::disk('local')->get($account->transactions()->sole()->proof_path);

        $this->assertLessThanOrEqual(strlen($jpeg), strlen($stored));
        $this->assertStringNotContainsString('GPS-rahasia', $stored);
        $this->assertSame([400, 300], array_slice(getimagesizefromstring($stored), 0, 2));
    }

    public function test_foto_profil_diganti_dan_dihapus_lewat_api(): void
    {
        Storage::fake('local');

        $user = User::factory()->create();
        $headers = [...$this->token($user), 'Accept' => 'application/json'];

        $this->get('/api/v1/profile/avatar', $headers)->assertNotFound();

        $first = $this->post('/api/v1/profile/avatar', ['avatar' => UploadedFile::fake()->image('a.jpg')], $headers)
            ->assertOk()->json('avatar');
        $oldPath = $user->fresh()->avatar_path;

        $second = $this->post('/api/v1/profile/avatar', ['avatar' => UploadedFile::fake()->image('b.jpg')], $headers)
            ->assertOk()->json('avatar');

        // Versi berganti supaya ponsel memuat ulang, dan foto lama tidak tertinggal.
        $this->assertNotSame($first, $second);
        Storage::disk('local')->assertMissing($oldPath);
        $this->getJson('/api/v1/me', $headers)->assertJsonPath('user.avatar', $second);
        $this->get('/api/v1/profile/avatar', $headers)->assertOk();

        $this->post('/api/v1/profile/avatar', ['avatar' => UploadedFile::fake()->create('x.pdf')], $headers)
            ->assertUnprocessable();

        $lastPath = $user->fresh()->avatar_path;
        Storage::disk('local')->assertExists($lastPath);

        $this->deleteJson('/api/v1/profile/avatar', [], $headers)->assertOk();
        Storage::disk('local')->assertMissing($lastPath);
        $this->getJson('/api/v1/me', $headers)->assertJsonPath('user.avatar', null);
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
