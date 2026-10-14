<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\Transaction;
use App\Models\User;
use App\Services\AccountStats;
use App\Services\AnnualReport;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Transfer antar akun: withdrawal di akun asal dan deposit di akun tujuan,
 * dicatat sekaligus dan saling menunjuk. Yang dijaga: saldo kedua akun cocok,
 * mata uang dikonversi dengan benar, dan tidak ada setengah transfer.
 */
class TransferTest extends TestCase
{
    use RefreshDatabase;

    private function account(User $user, string $name, string $currency, float $deposit = 0): Account
    {
        $account = $user->accounts()->create([
            'name' => $name,
            'currency' => $currency,
            'started_at' => CarbonImmutable::parse('2026-01-01'),
        ]);

        if ($deposit > 0) {
            $account->transactions()->create([
                'type' => 'deposit',
                'amount' => $deposit,
                'rate_idr' => in_array($currency, ['USD', 'USC'], true) ? 16000 : null,
                'occurred_at' => '2026-01-02',
            ]);
        }

        return $account;
    }

    private function balance(Account $account): float
    {
        return (new AccountStats($account))->balance();
    }

    public function test_seluruh_saldo_pindah_ke_akun_lain(): void
    {
        $user = User::factory()->create();
        $bersyukur = $this->account($user, 'Bersyukur', 'USD', 1000);
        $bertobatlah = $this->account($user, 'Bertobatlah', 'USD');

        $this->onAccount($bersyukur)->api('post', 'transfers', [
            'to_account_id' => $bertobatlah->id,
            'amount' => 1000,
            'occurred_at' => '2026-03-01',
            'note' => 'Pindah modal',
        ])->assertCreated()->assertJsonPath('message', 'Transfer ke "Bertobatlah" dicatat.');

        $this->assertEquals(0.0, $this->balance($bersyukur));
        $this->assertEquals(1000.0, $this->balance($bertobatlah));

        $out = $bersyukur->transactions()->where('type', 'withdrawal')->sole();
        $in = $bertobatlah->transactions()->sole();

        $this->assertSame($in->id, $out->transfer_pair_id);
        $this->assertSame($out->id, $in->transfer_pair_id);
        // Sekeluarga dolar: tidak ada rupiah yang berpindah, jadi tidak ada kurs.
        $this->assertNull($out->rate_idr);
        $this->assertNull($in->rate_idr);
        $this->assertSame('Pindah modal', $in->note);
        $this->assertNull($in->proof_path);

        // Daftar dana menyebut akun di seberangnya.
        $this->api('get', 'transactions?year=2026&month=3')
            ->assertJsonPath('items.data.0.transfer.account', 'Bertobatlah');
    }

    public function test_mata_uang_berbeda_dikonversi(): void
    {
        $user = User::factory()->create();
        $sen = $this->account($user, 'Sen', 'USC', 3700);
        $dolar = $this->account($user, 'Dolar', 'USD');
        $rupiah = $this->account($user, 'Rupiah', 'IDR');
        $senRupiah = $this->account($user, 'Sen Rupiah', 'IDC');

        $kirim = fn (Account $to, float $amount, ?float $received = null) => $this->onAccount($sen)
            ->api('post', 'transfers', [
                'to_account_id' => $to->id,
                'amount' => $amount,
                'received' => $received,
                'occurred_at' => '2026-03-01',
            ])->assertCreated();

        // Sekeluarga: 1000 USC = $10 dengan sendirinya — `received` tidak dipakai.
        $kirim($dolar, 1000, 999);
        // Lintas keluarga: yang diisi jumlah yang masuk, kursnya dihitung.
        $kirim($rupiah, 1000, 160_000);
        $kirim($senRupiah, 1000, 16_000_000);

        $this->assertEquals(700.0, $this->balance($sen));
        $this->assertEquals(10.0, $this->balance($dolar));
        $this->assertEquals(160_000.0, $this->balance($rupiah));
        $this->assertEquals(16_000_000.0, $this->balance($senRupiah));

        // Kursnya tercatat di sisi dolar saja: $10 jadi Rp160.000.
        $this->assertSame(['16000.000', '16000.000'], $sen->transactions()
            ->whereNotNull('transfer_pair_id')->whereNotNull('rate_idr')->pluck('rate_idr')->all());
        $this->assertNull($rupiah->transactions()->sole()->rate_idr);
    }

    public function test_kurs_dihitung_dari_jumlah_yang_diterima(): void
    {
        $user = User::factory()->create();
        $sen = $this->account($user, 'Sen', 'USC', 5000);
        $rupiah = $this->account($user, 'Rupiah', 'IDR', 1_000_000);

        // 1234 USC = $12,34 → Rp200.000: kurs 16.207,455 (tiga desimal), dan
        // jumlah yang masuk tercatat persis seperti diisi.
        $this->onAccount($sen)->api('post', 'transfers', [
            'to_account_id' => $rupiah->id,
            'amount' => 1234,
            'received' => 200_000,
            'occurred_at' => '2026-03-01',
        ])->assertCreated();

        $this->assertSame('16207.455', $sen->transactions()->where('type', 'withdrawal')->sole()->rate_idr);
        $this->assertSame('200000.00', $rupiah->transactions()->where('type', 'deposit')->latest('id')->first()->amount);

        // Arah sebaliknya: Rp320.000 jadi 2000 USC ($20) → 16.000.
        $this->onAccount($rupiah)->api('post', 'transfers', [
            'to_account_id' => $sen->id,
            'amount' => 320_000,
            'received' => 2000,
            'occurred_at' => '2026-03-02',
        ])->assertCreated();

        $this->assertSame('16000.000', $sen->transactions()->latest('id')->first()->rate_idr);
    }

    public function test_antar_akun_rupiah_tidak_butuh_kurs(): void
    {
        $user = User::factory()->create();
        $rupiah = $this->account($user, 'Rupiah', 'IDR', 50_000);
        $senRupiah = $this->account($user, 'Sen Rupiah', 'IDC');

        $this->onAccount($rupiah)->api('post', 'transfers', [
            'to_account_id' => $senRupiah->id,
            'amount' => 50_000,
            'occurred_at' => '2026-03-01',
        ])->assertCreated();

        $this->assertEquals(5_000_000.0, $this->balance($senRupiah));
    }

    public function test_ditolak_kalau_tidak_sah(): void
    {
        $user = User::factory()->create();
        $asal = $this->account($user, 'Asal', 'USD', 100);
        $tujuan = $this->account($user, 'Tujuan', 'USD');
        $rupiah = $this->account($user, 'Rupiah', 'IDR');
        $orangLain = $this->account(User::factory()->create(), 'Orang lain', 'USD');

        $this->onAccount($asal);
        $kirim = fn (array $data) => $this->api('post', 'transfers', [
            'to_account_id' => $tujuan->id,
            'amount' => 50,
            'occurred_at' => '2026-03-01',
            ...$data,
        ]);

        // Melebihi saldo, dan di bawah satuan terkecil.
        $kirim(['amount' => 100.01])->assertJsonValidationErrors(['amount' => '100,00 USD']);
        $kirim(['amount' => 0.004])->assertJsonValidationErrors('amount');
        // Dolar → rupiah tanpa jumlah yang diterima, atau dengan jumlah yang mustahil.
        $kirim(['to_account_id' => $rupiah->id])->assertJsonValidationErrors(['received' => 'jumlah yang masuk']);
        $kirim(['to_account_id' => $rupiah->id, 'received' => 0.01])->assertJsonValidationErrors(['received' => 'tidak masuk akal']);
        // Akun sendiri dan akun milik orang lain bukan tujuan yang sah.
        $kirim(['to_account_id' => $asal->id])->assertJsonValidationErrors('to_account_id');
        $kirim(['to_account_id' => $orangLain->id])->assertJsonValidationErrors('to_account_id');

        $this->assertSame(1, Transaction::count()); // hanya deposit awal
    }

    public function test_satu_sisi_tidak_bisa_diubah_dan_hapus_membuang_keduanya(): void
    {
        $user = User::factory()->create();
        $asal = $this->account($user, 'Asal', 'USD', 100);
        $tujuan = $this->account($user, 'Tujuan', 'USD');

        $this->onAccount($asal)->api('post', 'transfers', [
            'to_account_id' => $tujuan->id,
            'amount' => 60,
            'occurred_at' => '2026-03-01',
        ])->assertCreated();

        $in = $tujuan->transactions()->sole();

        $this->onAccount($tujuan)->api('post', 'transactions/'.$in->getRouteKey(), [
            'type' => 'deposit',
            'amount' => 999,
            'rate_idr' => 16000,
            'occurred_at' => '2026-03-01',
        ])->assertUnprocessable()->assertJsonPath('message', 'Transfer antar akun tidak bisa diubah. Hapus lalu catat ulang transfernya.');

        $this->api('delete', 'transactions/'.$in->getRouteKey())
            ->assertOk()
            ->assertJsonPath('message', 'Transfer dihapus dari kedua akun.');

        $this->assertSame(0, $tujuan->transactions()->count());
        $this->assertSame(1, $asal->transactions()->count()); // tinggal deposit awal
        $this->assertEquals(100.0, $this->balance($asal));
    }

    public function test_akun_seberang_dihapus_menyisakan_transaksi_biasa(): void
    {
        $user = User::factory()->create();
        $asal = $this->account($user, 'Asal', 'USD', 100);
        $tujuan = $this->account($user, 'Tujuan', 'USD');

        $this->onAccount($asal)->api('post', 'transfers', [
            'to_account_id' => $tujuan->id,
            'amount' => 60,
            'occurred_at' => '2026-03-01',
        ])->assertCreated();

        $this->api('delete', "accounts/{$asal->id}")->assertOk();

        $in = $tujuan->transactions()->sole();
        $this->assertNull($in->transfer_pair_id);
        $this->assertEquals(60.0, $this->balance($tujuan));
    }

    public function test_di_laporan_pajak_transfer_saling_menghapus(): void
    {
        $user = User::factory()->create();
        $asal = $this->account($user, 'Asal', 'USC', 10_000);
        $tujuan = $this->account($user, 'Tujuan', 'IDC');

        $this->onAccount($asal)->api('post', 'transfers', [
            'to_account_id' => $tujuan->id,
            'amount' => 10_000,
            'received' => 162_505_000, // Rp1.625.050 → kurs 16.250,5
            'occurred_at' => '2026-03-01',
        ])->assertCreated();

        $report = AnnualReport::build($user->accounts()->get(), 2026, 16000, '2026-12-31');
        [$a, $b] = $report['accounts'];

        // $100 × 16.250,5 = Rp1.625.050 keluar dari satu akun, masuk ke akun lain.
        $this->assertSame(1_625_050.0, $a['withdrawal_idr']);
        $this->assertSame(1_625_050.0, $b['deposit_idr']);
        $this->assertSame('Tujuan', $a['mutations'][1]['transfer']);
        $this->assertSame('Asal', $b['mutations'][0]['transfer']);
    }
}
