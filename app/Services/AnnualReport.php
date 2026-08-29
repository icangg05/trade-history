<?php

namespace App\Services;

use App\Models\Account;
use App\Models\Trade;
use App\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

/**
 * Bahan laporan tahunan untuk klarifikasi pajak. Mengembalikan array polos —
 * seluruh angkanya bisa diuji tanpa membongkar byte PDF, dan view-nya tinggal
 * mencetak. Tidak ada perhitungan di Blade.
 *
 * Semua agregat menumpang `AccountStats` supaya angka di laporan, dashboard,
 * dan analisa AI berasal dari satu sumber yang sama.
 *
 * ponytail: satu request memindai seluruh trade tiap akun (±340 baris × 3 akun
 * hari ini, jauh di bawah memory_limit 512M / 180s). Kalau nanti berat, potong
 * lampirannya jadi query terpaginasi atau render PDF-nya di queue.
 */
class AnnualReport
{
    /**
     * @param  Collection<int, Account>  $accounts
     * @param  float  $rate  Kurs IDR per USD untuk tahun pajak — dipakai laba/rugi
     *                       trading, yang tidak punya kurs per transaksi.
     * @param  string  $rateDate  Tanggal berlakunya kurs itu. Kurs tanpa tanggal tidak
     *                            bisa diperiksa ulang oleh siapa pun, jadi ikut dicetak.
     */
    public static function build(Collection $accounts, int $year, float $rate, string $rateDate): array
    {
        $from = CarbonImmutable::create($year, 1, 1)->startOfDay();
        $to = $from->endOfYear();

        $sections = $accounts
            // Akun yang dibuka setelah tahun pajak berakhir belum ada wujudnya
            // di tahun itu — bukan baris kosong, memang tidak relevan.
            ->filter(fn (Account $account) => $account->started_at->lte($to))
            ->map(fn (Account $account) => self::account($account, $from, $to, $rate))
            ->values();

        return [
            'year' => $year,
            'rate' => $rate,
            'rate_date' => $rateDate,
            'accounts' => $sections->all(),
            'total' => self::consolidate($sections),
        ];
    }

    /** Satu section akun: identitas, rekonsiliasi, kinerja, dan barisan mentahnya. */
    private static function account(Account $account, CarbonImmutable $from, CarbonImmutable $to, float $rate): array
    {
        // Satu instance dipakai ulang: `equityCurve()` di-memo per instance, jadi
        // instance baru per metrik berarti memindai ulang seluruh riwayat.
        $stats = new AccountStats($account);
        $currency = $account->currency;

        $mutations = $account->transactions()
            ->whereBetween('occurred_at', [$from->toDateString(), $to->toDateString()])
            ->orderBy('occurred_at')
            ->orderBy('id')
            ->get();

        $deposit = (float) $mutations->where('type', 'deposit')->sum('amount');
        $withdrawal = (float) $mutations->where('type', 'withdrawal')->sum('amount');

        $summary = $stats->summary($from, $to);
        $netPnl = (float) $summary['net_pnl'];

        // Saldo awal = posisi per 31 Desember tahun sebelumnya. Untuk tahun pertama
        // akun nilainya sama dengan `initial_balance` — modal awal itu tidak pernah
        // tercatat sebagai deposit, jadi laporan menyebutnya di catatan kaki.
        $opening = $stats->balance($from->subDay());
        $closing = $stats->balance($to);

        return [
            'name' => $account->name,
            'broker' => $account->broker,
            'account_number' => $account->account_number,
            'currency' => $currency,
            'started_at' => $account->started_at->toDateString(),
            'is_archived' => (bool) $account->is_archived,
            'initial_balance' => round((float) $account->initial_balance, 2),

            // Rekonsiliasi: awal + setor − tarik + laba/rugi = akhir. Identitas ini
            // seimbang menurut definisi karena AccountStats::balance() dibangun begitu;
            // yang dilaporkan justru selisihnya, supaya kalau suatu saat tidak nol
            // ketahuan di dokumen dan bukan disembunyikan.
            'opening_balance' => round($opening, 2),
            'deposit' => round($deposit, 2),
            'withdrawal' => round($withdrawal, 2),
            'net_pnl' => round($netPnl, 2),
            'closing_balance' => round($closing, 2),
            'reconciliation_gap' => round($closing - ($opening + $deposit - $withdrawal + $netPnl), 2),

            'opening_balance_idr' => self::idr($opening, $rate, $currency),
            'deposit_idr' => self::mutationIdr($mutations, 'deposit', $rate, $currency),
            'withdrawal_idr' => self::mutationIdr($mutations, 'withdrawal', $rate, $currency),
            'net_pnl_idr' => self::idr($netPnl, $rate, $currency),
            'closing_balance_idr' => self::idr($closing, $rate, $currency),

            'summary' => $summary,
            // `by_setup` sengaja tidak ikut: trade bertag "BOS, FVG" masuk dua bucket,
            // jadi jumlahnya melebihi total transaksi. Aman untuk evaluasi strategi,
            // menyesatkan di dokumen pajak.
            'by_symbol' => self::withIdr($summary['by_symbol'], $rate, $currency),
            'by_direction' => self::withIdr($summary['by_direction'], $rate, $currency),
            'monthly' => array_map(
                fn (array $m) => [...$m, 'pnl_idr' => self::idr($m['pnl'], $rate, $currency)],
                $stats->monthlyPnl(12, $to),
            ),
            'mutations' => $mutations->map(fn (Transaction $t) => [
                'occurred_at' => $t->occurred_at->toDateString(),
                'type' => $t->type,
                'amount' => (float) $t->amount,
                // Kurs baris ini kalau tercatat, kurs tahunan kalau barisnya lama.
                'rate_idr' => $t->rate_idr === null ? null : (float) $t->rate_idr,
                'amount_idr' => self::idr((float) $t->amount, (float) ($t->rate_idr ?? $rate), $currency),
                'has_proof' => filled($t->proof_path),
                // Bukti dibuka lewat route yang sudah mengecek kepemilikan; tautannya
                // absolut supaya tetap bisa diklik dari dalam PDF.
                'proof_url' => filled($t->proof_path) ? route('transactions.proof', $t) : null,
                'note' => $t->note,
            ])->all(),
            'trades' => $stats->trades($from, $to)->map(fn (Trade $t) => [
                'opened_at' => $t->opened_at->format('Y-m-d H:i'),
                'closed_at' => $t->closed_at?->format('Y-m-d H:i'),
                'symbol' => $t->symbol,
                'direction' => $t->direction,
                'lot' => $t->lot === null ? null : (float) $t->lot,
                'entry_price' => $t->entry_price === null ? null : (float) $t->entry_price,
                'exit_price' => $t->exit_price === null ? null : (float) $t->exit_price,
                'sl_price' => $t->sl_price === null ? null : (float) $t->sl_price,
                'tp_price' => $t->tp_price === null ? null : (float) $t->tp_price,
                'pnl' => (float) $t->pnl,
                'pnl_idr' => self::idr((float) $t->pnl, $rate, $currency),
                'status' => $t->status,
            ])->all(),
        ];
    }

    /**
     * Total lintas akun hanya sah dalam rupiah — akun USD, USC dan IDR tidak bisa
     * dijumlahkan apa adanya. Kebetulan itu juga satuan yang diminta pajak.
     */
    private static function consolidate(Collection $sections): array
    {
        $sum = fn (string $key) => round($sections->sum($key), 2);

        return [
            'opening_balance_idr' => $sum('opening_balance_idr'),
            'deposit_idr' => $sum('deposit_idr'),
            'withdrawal_idr' => $sum('withdrawal_idr'),
            'net_pnl_idr' => $sum('net_pnl_idr'),
            'closing_balance_idr' => $sum('closing_balance_idr'),
            // Sebagian pemeriksa hanya menganggap uang yang benar-benar keluar dari
            // broker sebagai penghasilan terealisasi. Angkanya ditampilkan berdampingan
            // dengan laba/rugi buku supaya pertanyaannya terjawab sebelum ditanyakan.
            'net_cash_idr' => round($sections->sum('withdrawal_idr') - $sections->sum('deposit_idr'), 2),
            'total_trades' => (int) $sections->sum(fn (array $a) => $a['summary']['total_trades']),
        ];
    }

    /**
     * Rincian `by_*` dari `summary()` ditambahi kolom rupiahnya di sini — view-nya
     * mencetak, tidak menghitung.
     */
    private static function withIdr(array $breakdown, float $rate, string $currency): array
    {
        return array_map(
            fn (array $row) => [...$row, 'pnl_idr' => self::idr($row['pnl'], $rate, $currency)],
            $breakdown,
        );
    }

    /** Setor/tarik dikonversi memakai kurs hari transaksinya masing-masing. */
    private static function mutationIdr(Collection $mutations, string $type, float $rate, string $currency): float
    {
        return round($mutations->where('type', $type)->sum(
            fn (Transaction $t) => self::idr((float) $t->amount, (float) ($t->rate_idr ?? $rate), $currency),
        ), 2);
    }

    /**
     * Cerminan `toIdr()` di useFormat.ts: kurs selalu per dolar, dan akun sen (USC)
     * bernilai 1/100 dolar per unit.
     */
    private static function idr(float $amount, float $rate, string $currency): float
    {
        return round(match ($currency) {
            'IDR' => $amount,
            'USC' => $amount / 100 * $rate,
            default => $amount * $rate,
        }, 2);
    }
}
