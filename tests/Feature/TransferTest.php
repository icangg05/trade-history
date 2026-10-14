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
            'rate_idr' => 16250.125,
            'occurred_at' => '2026-03-01',
            'note' => 'Pindah modal',
        ])->assertCreated()->assertJsonPath('message', 'Transfer ke "Bertobatlah" dicatat.');

        $this->assertEquals(0.0, $this->balance($bersyukur));
        $this->assertEquals(1000.0, $this->balance($bertobatlah));

        $out = $bersyukur->transactions()->where('type', 'withdrawal')->sole();
        $in = $bertobatlah->transactions()->sole();

        $this->assertSame($in->id, $out->transfer_pair_id);
        $this->assertSame($out->id, $in->transfer_pair_id);
        $this->assertSame('16250.125', $in->rate_idr);
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

        $kirim = fn (Account $to, float $amount, ?float $rate = 16000) => $this->onAccount($sen)
            ->api('post', 'transfers', [
                'to_account_id' => $to->id,
                'amount' => $amount,
                'rate_idr' => $rate,
                'occurred_at' => '2026-03-01',
            ])->assertCreated();

        // Sekeluarga: 1000 USC = $10, kursnya tidak mengubah apa pun.
        $kirim($dolar, 1000);
        // Lintas keluarga: 1000 USC = $10 × 16.000 = Rp160.000 = 16.000.000 IDC.
        $kirim($rupiah, 1000);
        $kirim($senRupiah, 1000);

        $this->assertEquals(700.0, $this->balance($sen));
        $this->assertEquals(10.0, $this->balance($dolar));
        $this->assertEquals(160_000.0, $this->balance($rupiah));
        $this->assertEquals(16_000_000.0, $this->balance($senRupiah));

        // Sisi rupiah tidak menyimpan kurs dolar.
        $this->assertNull($rupiah->transactions()->sole()->rate_idr);
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
        $orangLain = $this->account(User::factory()->create(), 'Orang lain', 'USD');

        $this->onAccount($asal);
        $kirim = fn (array $data) => $this->api('post', 'transfers', [
            'to_account_id' => $tujuan->id,
            'amount' => 50,
            'rate_idr' => 16000,
            'occurred_at' => '2026-03-01',
            ...$data,
        ]);

        // Melebihi saldo, tanpa kurs untuk akun dolar, kurs empat desimal.
        $kirim(['amount' => 100.01])->assertJsonValidationErrors(['amount' => '100,00 USD']);
        $kirim(['rate_idr' => null])->assertJsonValidationErrors('rate_idr');
        $kirim(['rate_idr' => 16000.1234])->assertJsonValidationErrors(['rate_idr' => '3 angka di belakang koma']);
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
            'rate_idr' => 16000,
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
            'rate_idr' => 16000,
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
            'rate_idr' => 16250.5,
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
