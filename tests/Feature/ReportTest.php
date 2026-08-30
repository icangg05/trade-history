<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\User;
use App\Services\AnnualReport;
use App\Services\Uploads;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Laporan ini dipegang saat pajak meminta klarifikasi, jadi yang dijaga di sini
 * bukan tampilannya melainkan angkanya: rekonsiliasi saldo harus tertutup,
 * tahun lain tidak boleh bocor masuk, dan tidak satu pun akun boleh hilang.
 */
class ReportTest extends TestCase
{
    use RefreshDatabase;

    private function account(User $user, array $overrides = []): Account
    {
        return $user->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => CarbonImmutable::parse('2025-01-01'),
            ...$overrides,
        ]);
    }

    private function trade(Account $account, string $closedAt, float $pnl): void
    {
        $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'exit_price' => 110,
            'pnl' => $pnl,
            'opened_at' => $closedAt,
            'closed_at' => $closedAt,
        ]);
    }

    public function test_rekonsiliasi_saldo_tahunan_seimbang(): void
    {
        $account = $this->account(User::factory()->create());

        $account->transactions()->create(['type' => 'deposit', 'amount' => 500, 'rate_idr' => 16000, 'occurred_at' => '2025-03-01']);
        $account->transactions()->create(['type' => 'withdrawal', 'amount' => 200, 'rate_idr' => 16200, 'occurred_at' => '2025-06-01']);

        $this->trade($account, '2025-04-10 12:00', 300);
        $this->trade($account, '2025-09-10 12:00', -150);

        // Tahun lain: tidak boleh ikut terhitung, tapi harus terbawa ke saldo awal 2026.
        $this->trade($account, '2024-05-05 12:00', 90);
        $account->transactions()->create(['type' => 'deposit', 'amount' => 100, 'rate_idr' => 15000, 'occurred_at' => '2024-02-01']);

        $report = AnnualReport::build($account->newCollection([$account]), 2025, 16500, '2025-12-31');
        $a = $report['accounts'][0];

        // Saldo awal 2025 = 1000 modal + 100 deposit 2024 + 90 laba 2024
        $this->assertSame(1190.0, $a['opening_balance']);
        $this->assertSame(500.0, $a['deposit']);
        $this->assertSame(200.0, $a['withdrawal']);
        $this->assertSame(150.0, $a['net_pnl']);            // 300 − 150, tanpa 2024
        $this->assertSame(1640.0, $a['closing_balance']);   // 1190 + 500 − 200 + 150
        $this->assertSame(0.0, $a['reconciliation_gap']);
        $this->assertSame(2, $a['summary']['total_trades']);

        // Setor/tarik memakai kurs harinya sendiri, laba/rugi memakai kurs tahunan.
        $this->assertSame(8000000.0, $a['deposit_idr']);        // 500 × 16.000
        $this->assertSame(3240000.0, $a['withdrawal_idr']);     // 200 × 16.200
        $this->assertSame(2475000.0, $a['net_pnl_idr']);        // 150 × 16.500
    }

    public function test_rekap_bulanan_mengikuti_tahun_pajak_bukan_dua_belas_bulan_terakhir(): void
    {
        CarbonImmutable::setTestNow('2026-08-20');

        $account = $this->account(User::factory()->create());
        $this->trade($account, '2025-02-14 12:00', 250);

        $report = AnnualReport::build($account->newCollection([$account]), 2025, 16000, '2025-12-31');
        $monthly = $report['accounts'][0]['monthly'];

        $this->assertCount(12, $monthly);
        $this->assertSame('2025-01', $monthly[0]['month']);
        $this->assertSame('2025-12', $monthly[11]['month']);
        $this->assertSame(250.0, $monthly[1]['pnl']);
    }

    public function test_akun_yang_diarsipkan_tetap_masuk_laporan(): void
    {
        $user = User::factory()->create();
        $aktif = $this->account($user, ['name' => 'Aktif']);
        $arsip = $this->account($user, ['name' => 'Arsip', 'is_archived' => true]);

        $this->trade($aktif, '2025-05-05 12:00', 100);
        $this->trade($arsip, '2025-05-06 12:00', 400);

        $report = AnnualReport::build($user->accounts()->orderBy('name')->get(), 2025, 16000, '2025-12-31');

        $this->assertCount(2, $report['accounts']);
        $this->assertSame(8000000.0, $report['total']['net_pnl_idr']); // (100 + 400) × 16.000
    }

    public function test_akun_yang_dibuka_setelah_tahun_pajak_dilewati(): void
    {
        $user = User::factory()->create();
        $this->account($user, ['started_at' => CarbonImmutable::parse('2026-03-01')]);

        $report = AnnualReport::build($user->accounts()->get(), 2025, 16000, '2025-12-31');

        $this->assertSame([], $report['accounts']);
    }

    public function test_akun_sen_dikonversi_dengan_pembagi_seratus(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user, ['currency' => 'USC', 'initial_balance' => 0]);

        $this->trade($account, '2025-07-07 12:00', 3700); // 3700 sen = 37 dolar

        $report = AnnualReport::build($user->accounts()->get(), 2025, 16000, '2025-12-31');

        $this->assertSame(592000.0, $report['accounts'][0]['net_pnl_idr']); // 37 × 16.000
    }

    public function test_realisasi_kas_memakai_penarikan_dikurangi_setoran(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);

        $account->transactions()->create(['type' => 'deposit', 'amount' => 100, 'rate_idr' => 16000, 'occurred_at' => '2025-02-01']);
        $account->transactions()->create(['type' => 'withdrawal', 'amount' => 300, 'rate_idr' => 16000, 'occurred_at' => '2025-11-01']);

        $report = AnnualReport::build($user->accounts()->get(), 2025, 16000, '2025-12-31');

        $this->assertSame(3200000.0, $report['total']['net_cash_idr']); // (300 − 100) × 16.000
    }

    public function test_halaman_laporan_menawarkan_tahun_sejak_akun_tertua(): void
    {
        CarbonImmutable::setTestNow('2026-08-20');

        $user = User::factory()->create();
        $account = $this->account($user, ['started_at' => CarbonImmutable::parse('2024-06-01')]);

        $props = $this
            ->actingAs($user)
            ->withSession(['current_account_id' => $account->id])
            ->get('/reports')
            ->assertOk()
            ->viewData('page')['props'];

        $this->assertSame([2026, 2025, 2024], $props['years']);
        $this->assertCount(1, $props['accounts']);
        // Form unduhan memakai POST biasa, jadi tokennya harus ikut terbagi.
        $this->assertNotEmpty($props['csrf']);
    }

    /** Blade-nya dirender langsung: memeriksa HTML jauh lebih murah daripada byte PDF. */
    private function html(User $user, array $identity = [], float $rate = 16000): string
    {
        // PNG 1×1 transparan: view-nya cuma perlu URI yang sah, bukan watermark asli.
        $pixel = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

        return view('reports.annual', [
            'report' => AnnualReport::build($user->accounts()->get(), 2025, $rate, '2025-12-31'),
            'brand' => ['name' => config('app.name'), 'logo' => $pixel, 'watermark' => $pixel],
            'identity' => [...['name' => 'Nama Uji', 'npwp' => null, 'address' => null], ...$identity],
            'printedAt' => CarbonImmutable::parse('2026-01-10 09:00'),
        ])->render();
    }

    public function test_harga_lampiran_membuang_nol_di_belakang_koma(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);

        // decimal(18,5) selalu kembali sebagai 4523.13000 / 4391.32100 / 4400.00000.
        $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 4523.13,
            'sl_price' => 4400,
            'tp_price' => 4391.321,
            'exit_price' => 4523.13,
            'pnl' => 50,
            'opened_at' => '2025-05-05 10:00',
            'closed_at' => '2025-05-05 12:00',
        ]);

        $html = $this->html($user);

        $this->assertStringContainsString('4.523,13', $html);
        $this->assertStringNotContainsString('4.523,13000', $html);
        $this->assertStringContainsString('4.391,321', $html);   // desimal bermakna tetap utuh
        $this->assertStringContainsString('4.400,00', $html);    // minimal dua desimal
        $this->assertStringNotContainsString('4.400,00000', $html);
    }

    public function test_kurs_dicetak_bersama_tanggal_berlakunya(): void
    {
        $user = User::factory()->create();
        $this->account($user);

        $this->assertStringContainsString('31 Desember 2025', $this->html($user));
    }

    public function test_bukti_transfer_jadi_tautan_yang_bisa_diklik(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);

        $berbukti = $account->transactions()->create(['type' => 'deposit', 'amount' => 100, 'rate_idr' => 16000, 'occurred_at' => '2025-02-01', 'proof_path' => 'proofs/a.jpg']);
        $account->transactions()->create(['type' => 'deposit', 'amount' => 50, 'rate_idr' => 16000, 'occurred_at' => '2025-03-01']);

        $html = $this->html($user);

        // Tautan bertanda tangan, bukan route bersesi: yang memegang PDF-nya boleh
        // membuka tanpa punya akun di aplikasi ini. Tidak ada `expires` di URL —
        // hitungan mundurnya baru mulai saat tautannya dibuka.
        $this->assertMatchesRegularExpression(
            '#href="https?://[^"]+/proofs/'.$berbukti->getRouteKey().'\?signature=[0-9a-f]+"#',
            $html,
        );
        $this->assertStringContainsString('Lihat bukti', $html);
        // Id berurutan tidak boleh terbaca dari dokumen yang berpindah tangan.
        $this->assertStringNotContainsString('/proofs/'.$berbukti->id.'/', $html);
        // Baris tanpa bukti tidak boleh ikut punya tautan (teks yang sama juga muncul
        // di catatan kaki, jadi yang dihitung tautannya — bukan kalimatnya).
        $this->assertSame(1, substr_count($html, '>Lihat bukti</a>'));
        $this->assertStringContainsString('Tidak ada', $html);
    }

    public function test_tautan_dokumen_menerbitkan_alamat_pandang_berumur_15_detik(): void
    {
        $link = $this->proofUrl($this->tautanBukti());

        // Laporan yang baru dibaca sebulan kemudian tetap harus bisa dibuka.
        $this->travel(30)->days();

        // Tidak ada actingAs di sini: persis posisi petugas yang cuma pegang PDF-nya.
        // Tautan di dokumen tidak menyajikan berkasnya, ia melempar ke alamat pandang.
        $view = $this->get($link)->assertRedirect()->headers->get('Location');

        $this->assertStringContainsString('/view?expires=', $view);
        $this->get($view)->assertOk();

        // Masih di dalam jendelanya — memuat ulang alamat yang sama tetap boleh.
        $this->travel(14)->seconds();
        $this->get($view)->assertOk();

        // Lewat 15 detik alamat itu benar-benar mati, dan matinya 404 bukan 403.
        $this->travel(2)->seconds();
        $this->get($view)->assertNotFound();
    }

    public function test_klik_ulang_dari_dokumen_memberi_jendela_yang_baru(): void
    {
        $link = $this->proofUrl($this->tautanBukti());

        $lama = $this->get($link)->assertRedirect()->headers->get('Location');
        $this->travel(16)->seconds();
        $this->get($lama)->assertNotFound();

        // Inilah bedanya dengan alamat pandang: tautan di dokumen tidak pernah
        // hangus. Pemegang laporan mengklik lagi dan dapat 15 detik yang baru.
        $baru = $this->get($link)->assertRedirect()->headers->get('Location');

        $this->assertNotSame($lama, $baru);
        $this->get($baru)->assertOk();
    }

    public function test_bukti_disajikan_di_halaman_bukan_sebagai_berkas_telanjang(): void
    {
        $link = $this->proofUrl($this->tautanBukti());
        $view = $this->get($link)->assertRedirect()->headers->get('Location');

        $html = $this->get($view)->assertOk()->assertHeader('content-type', 'text/html; charset=UTF-8')->getContent();

        // Gambarnya ditanam ke halaman, jadi tidak ada alamat berkas kedua yang
        // bisa dibuka atau dibagikan lepas dari halaman ini.
        $this->assertStringContainsString('<img src="data:', $html);
        $this->assertStringContainsString(base64_encode('isi berkas'), $html);

        // Penghalang klik kanan & seret. Kosmetik — bukan yang menahan sebaran.
        $this->assertStringContainsString("'contextmenu', 'dragstart'", $html);
    }

    public function test_alamat_pandang_tidak_bisa_dikarang_sendiri(): void
    {
        $user = $this->tautanBukti();
        $hash = $user->accounts()->sole()->transactions()->sole()->getRouteKey();

        // Tanpa tanda tangan, atau dengan tanda tangan asal-asalan: tetap 404.
        $this->get('/proofs/'.$hash.'/view')->assertNotFound();
        $this->get('/proofs/'.$hash.'/view?expires=99999999999&signature=abc')->assertNotFound();
    }

    /** Satu akun dengan satu mutasi berbukti, berkasnya benar-benar ada di disk. */
    private function tautanBukti(): User
    {
        Storage::fake(Uploads::DISK);
        Storage::disk(Uploads::DISK)->put('proofs/a.jpg', 'isi berkas');

        $user = User::factory()->create();
        $this->account($user)->transactions()->create(['type' => 'deposit', 'amount' => 100, 'rate_idr' => 16000, 'occurred_at' => '2025-02-01', 'proof_path' => 'proofs/a.jpg']);

        return $user;
    }

    /** Tautan "Lihat bukti" seperti yang benar-benar tercetak di laporan. */
    private function proofUrl(User $user): string
    {
        preg_match('#href="([^"]+/proofs/[^"]+)"#', $this->html($user), $m);

        return html_entity_decode($m[1]);
    }

    public function test_akun_rupiah_tidak_mencetak_kolom_mata_uang_kembar(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user, ['currency' => 'IDR', 'initial_balance' => 5000000]);
        $this->trade($account, '2025-05-05 12:00', 250000);
        $account->transactions()->create(['type' => 'withdrawal', 'amount' => 1000000, 'occurred_at' => '2025-06-01']);

        $html = $this->html($user);

        // `$cur()` menempelkan kode mata uang di belakang angka. Untuk akun rupiah
        // kolom itu kembar dengan kolom Rupiah, jadi tidak boleh tercetak sama sekali.
        $this->assertStringNotContainsString(' IDR', $html);
        $this->assertStringNotContainsString('(IDR)', $html);
        // Rekap bulanan tinggal satu kolom laba/rugi bersih, bukan dua yang sebangun.
        $this->assertSame(1, substr_count($html, 'Laba/Rugi Bersih (Rp)'));
        // Kurs juga tidak berarti apa-apa untuk akun yang memang sudah rupiah.
        $this->assertStringNotContainsString('Kurs (Rp/USD)', $html);

        // Yang tersisa tetap kolom rupiahnya, dengan angka yang utuh.
        $this->assertStringContainsString('Rp5.000.000', $html);
        $this->assertStringContainsString('Rp250.000', $html);
        $this->assertStringContainsString('-Rp1.000.000', $html);
    }

    public function test_akun_valuta_asing_tetap_punya_dua_kolom(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);
        $this->trade($account, '2025-05-05 12:00', 120);
        $account->transactions()->create(['type' => 'deposit', 'amount' => 100, 'rate_idr' => 16000, 'occurred_at' => '2025-02-01']);

        $html = $this->html($user);

        $this->assertStringContainsString('120,00 USD', $html);
        $this->assertStringContainsString('Rp1.920.000', $html);
        $this->assertStringContainsString('Kurs (Rp/USD)', $html);
    }

    public function test_unduh_menghasilkan_berkas_pdf(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);
        $this->trade($account, '2025-05-05 12:00', 120);

        $response = $this
            ->actingAs($user)
            ->withSession(['current_account_id' => $account->id])
            ->post('/reports/pdf', [
                'year' => 2025,
                'rate' => 16000,
                'rate_date' => '2025-12-31',
                'name' => 'Nama Uji',
                'npwp' => '00.000.000.0-000.000',
                'address' => 'Jalan Uji 1',
            ]);

        $response->assertOk();
        $response->assertHeader('content-type', 'application/pdf');
        $this->assertStringStartsWith('%PDF', $response->getContent());
    }

    /**
     * Kurs ditulis dengan koma seperti kebiasaan Indonesia. Desimalnya tidak boleh
     * hilang di mana pun: angka yang dipakai menghitung dan angka yang tercetak di
     * laporan harus sama persis.
     */
    public function test_kurs_menerima_koma_desimal(): void
    {
        $kasus = [
            '17757,40' => 17757.40,     // koma desimal
            '17.757,40' => 17757.40,    // titik ribuan + koma desimal
            '17757.40' => 17757.40,     // titik desimal gaya mesin
            '16250' => 16250.0,         // bulat tanpa pemisah
        ];

        foreach ($kasus as $masukan => $harapan) {
            $user = User::factory()->create();
            $account = $this->account($user);
            $this->trade($account, '2025-05-05 12:00', 100);

            $this
                ->actingAs($user)
                ->withSession(['current_account_id' => $account->id])
                ->post('/reports/pdf', [
                    'year' => 2025,
                    'rate' => (string) $masukan,
                    'rate_date' => '2025-12-31',
                    'name' => 'Nama Uji',
                ])
                ->assertOk()
                ->assertHeader('content-type', 'application/pdf');

            // Angka yang benar-benar dipakai menghitung, bukan sekadar yang tercetak.
            $report = AnnualReport::build($user->accounts()->get(), 2025, $harapan, '2025-12-31');
            $this->assertSame(round(100 * $harapan, 2), $report['accounts'][0]['net_pnl_idr'], (string) $masukan);

            $this->assertStringContainsString(
                'Rp'.number_format($harapan, 2, ',', '.').' per 1 USD',
                $this->html($user, [], $harapan),
                (string) $masukan,
            );
        }
    }

    public function test_kurs_yang_bukan_angka_ditolak(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);

        $this
            ->actingAs($user)
            ->withSession(['current_account_id' => $account->id])
            ->post('/reports/pdf', [
                'year' => 2025,
                'rate' => 'enam belas ribu',
                'rate_date' => '2025-12-31',
                'name' => 'Nama Uji',
            ])
            ->assertSessionHasErrors('rate');
    }

    /**
     * Watermark digambar GD dengan font bawaan dompdf: container ini tidak punya
     * satu pun font sistem, jadi kalau jalurnya bergeser gambarnya lahir kosong.
     */
    public function test_watermark_dan_logo_ikut_tertanam_di_pdf(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);
        $this->trade($account, '2025-05-05 12:00', 100);

        $pdf = $this
            ->actingAs($user)
            ->withSession(['current_account_id' => $account->id])
            ->post('/reports/pdf', [
                'year' => 2025,
                'rate' => '16000',
                'rate_date' => '2025-12-31',
                'name' => 'Nama Uji',
            ])
            ->assertOk()
            ->getContent();

        // Logo + watermark keduanya masuk sebagai XObject gambar.
        $this->assertGreaterThanOrEqual(2, substr_count($pdf, '/Subtype /Image'));
    }

    /**
     * Nomor akun broker adalah satu-satunya penanda yang menyambungkan laporan ini
     * ke statement resmi broker. Tanpa itu pemeriksa tidak bisa memastikan kedua
     * dokumen membicarakan akun yang sama.
     */
    public function test_nomor_akun_broker_tercetak_di_laporan(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user, ['broker' => 'Exness', 'account_number' => '123456789']);
        $this->trade($account, '2025-05-05 12:00', 100);

        $report = AnnualReport::build($user->accounts()->get(), 2025, 16000, '2025-12-31');

        $this->assertSame('123456789', $report['accounts'][0]['account_number']);
        $this->assertStringContainsString('123456789', $this->html($user));
    }

    public function test_akun_milik_pengguna_lain_tidak_ikut_dilaporkan(): void
    {
        $user = User::factory()->create();
        $account = $this->account($user);
        $this->trade($account, '2025-05-05 12:00', 100);

        $orang_lain = $this->account(User::factory()->create(), ['name' => 'Punya Orang Lain']);
        $this->trade($orang_lain, '2025-05-05 12:00', 999);

        $report = AnnualReport::build(
            Account::query()->where('user_id', $user->id)->get(),
            2025,
            16000,
            '2025-12-31',
        );

        $this->assertCount(1, $report['accounts']);
        $this->assertSame('Uji', $report['accounts'][0]['name']);
        $this->assertSame(1600000.0, $report['total']['net_pnl_idr']); // 100 × 16.000, bukan 999
    }
}
