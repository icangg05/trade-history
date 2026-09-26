<?php

namespace App\Http\Controllers;

use App\Models\Account;
use App\Models\Transaction;
use App\Services\AccountStats;
use App\Services\Uploads;
use App\Support\Hashid;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response as HttpResponse;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class TransactionController extends Controller
{
    private const FOLDER = 'proofs';

    /**
     * Bukti transfer masuk laporan pajak, jadi tulisannya harus tetap terbaca:
     * sisi terpanjang 2000 px dengan kualitas JPEG 85 masih tajam untuk
     * screenshot mutasi rekening maupun foto struk.
     */
    private const PROOF_SIDE = 2000;

    /**
     * Foto dari galeri ponsel dikirim apa adanya (lihat transaction_form.dart),
     * jadi batasnya cukup untuk foto kamera 50 MP. Tetap di bawah
     * upload_max_filesize (16M) di docker/php.ini.
     */
    private const PROOF_MAX_KB = 15 * 1024;

    public function index(Request $request): Response|JsonResponse
    {
        $account = $request->currentAccount();
        $stats = new AccountStats($account);

        // Bawaannya periode berjalan — yang dilihat orang sembilan dari sepuluh
        // kali. "all" yang eksplisit membuka seluruh riwayat; bulan hanya berarti
        // kalau tahunnya juga dipilih.
        $now = CarbonImmutable::now();
        $year = $request->string('year')->toString() === 'all'
            ? null
            : ($request->integer('year') ?: $now->year);
        $month = $year === null || $request->string('month')->toString() === 'all'
            ? null
            : (min(max($request->integer('month'), 0), 12) ?: $now->month);

        $scoped = fn () => $account->transactions()
            ->when($year, fn ($q) => $q->whereYear('occurred_at', $year))
            ->when($month, fn ($q) => $q->whereMonth('occurred_at', $month));

        // Satu query untuk kedua total sekaligus: nominal mata uang akun, dan
        // nilai rupiahnya memakai kurs yang tercatat per transaksi.
        $flow = $scoped()
            ->selectRaw('type, SUM(amount) as total, SUM(amount * COALESCE(rate_idr, 0)) as total_idr')
            ->groupBy('type')
            ->get()
            ->keyBy('type');

        // Kurs dicatat per dolar; akun sen (USC) bernilai 1/100 dolar per unit.
        $cents = $account->currency === 'USC' ? 100 : 1;

        // Rentang tahun diambil dari dua nilai agregat, bukan daftar tanggal —
        // MIN/MAX portabel antara MySQL & SQLite, DISTINCT YEAR() tidak. Tahun
        // berjalan selalu ikut walau belum ada transaksinya: itu pilihan bawaan.
        $span = $account->transactions()->selectRaw('MIN(occurred_at) as a, MAX(occurred_at) as b')->first();
        $newest = max((int) substr($span?->b ?? '', 0, 4), $now->year);
        $oldest = min((int) substr($span?->a ?? '', 0, 4) ?: $now->year, $now->year);

        return $this->page('Transactions', [
            'filters' => ['year' => $year, 'month' => $month],
            'years' => range($newest, $oldest),
            'items' => $scoped()
                ->orderByDesc('occurred_at')
                ->orderByDesc('id')
                ->paginate(30)
                ->withQueryString()
                ->through(fn (Transaction $t) => [
                    ...$t->only('type', 'note'),
                    'id' => $t->getRouteKey(),
                    'amount' => (float) $t->amount,
                    'rate_idr' => $t->rate_idr === null ? null : (float) $t->rate_idr,
                    'occurred_at' => $t->occurred_at->toDateString(),
                    'has_proof' => filled($t->proof_path),
                    // Alamat bukti selalu sama; penanda ini yang berubah saat
                    // buktinya diganti, supaya ponsel tidak menampilkan cache lama.
                    'proof_version' => $t->proof_path ? substr(md5($t->proof_path), 0, 8) : null,
                ]),
            'totals' => [
                'deposit' => (float) ($flow['deposit']->total ?? 0),
                'withdrawal' => (float) ($flow['withdrawal']->total ?? 0),
                'deposit_idr' => (float) ($flow['deposit']->total_idr ?? 0) / $cents,
                'withdrawal_idr' => (float) ($flow['withdrawal']->total_idr ?? 0) / $cents,
                'balance' => $stats->balance(),
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse|JsonResponse
    {
        $account = $request->currentAccount();

        // Bukti transfer wajib saat dicatat — ini catatan uang sungguhan.
        $data = $request->validate($this->rules($account, ['required', 'image', 'max:'.self::PROOF_MAX_KB]));
        $this->ensureAffordable($account, $data);

        $data['proof_path'] = Uploads::image($request->file('proof'), self::FOLDER.'/'.$account->id, self::PROOF_SIDE);
        unset($data['proof']);

        $transaction = $account->transactions()->create($data);

        return $this->done(
            $data['type'] === 'deposit' ? 'Deposit dicatat.' : 'Withdrawal dicatat.',
            data: ['id' => $transaction->getRouteKey()],
            status: 201,
        );
    }

    /**
     * Perbaiki baris yang sudah tercatat. Salah ketik nominal atau kurs dulu
     * hanya bisa dibetulkan dengan menghapus lalu mengunggah ulang buktinya.
     *
     * Buktinya sendiri opsional di sini: yang lama dipertahankan selama tidak
     * ada berkas baru, jadi memperbaiki angka tidak menuntut unggah ulang.
     */
    public function update(Request $request, Transaction $transaction): RedirectResponse|JsonResponse
    {
        $account = $request->currentAccount();

        $data = $request->validate($this->rules($account, ['nullable', 'image', 'max:'.self::PROOF_MAX_KB]));
        $this->ensureAffordable($account, $data, $transaction);

        if ($request->hasFile('proof')) {
            $lama = $transaction->proof_path;
            $data['proof_path'] = Uploads::image($request->file('proof'), self::FOLDER.'/'.$account->id, self::PROOF_SIDE);
            Uploads::delete($lama);
        }

        unset($data['proof']);

        $transaction->update($data);

        return $this->done('Transaksi diperbarui.');
    }

    /**
     * Withdrawal tidak boleh melebihi saldo akun sekarang — uang yang tidak
     * ada tidak bisa ditarik. Saat memperbaiki, baris yang sedang diubah
     * dikeluarkan dulu dari hitungan: withdrawal 500 yang diubah jadi 600
     * hanya butuh tambahan 100.
     *
     * @param  array<string, mixed>  $data
     */
    private function ensureAffordable(Account $account, array $data, ?Transaction $editing = null): void
    {
        if ($data['type'] !== 'withdrawal') {
            return;
        }

        $current = $editing === null ? 0 : ($editing->type === 'deposit' ? 1 : -1) * (float) $editing->amount;
        $available = round((new AccountStats($account))->balance() - $current, 2);

        if ((float) $data['amount'] > $available) {
            throw ValidationException::withMessages([
                'amount' => 'Melebihi saldo akun. Yang bisa ditarik paling banyak '
                    .number_format(max($available, 0), 2, ',', '.').' '.$account->currency.'.',
            ]);
        }
    }

    /**
     * Aturan yang sama untuk mencatat dan memperbaiki; yang berbeda hanya bukti
     * transfernya — wajib saat lahir, opsional saat diperbaiki.
     *
     * @param  list<string>  $proof
     * @return array<string, mixed>
     */
    private function rules($account, array $proof): array
    {
        return [
            'type' => ['required', 'in:deposit,withdrawal'],
            'amount' => ['required', 'numeric', 'gt:0'],
            // Kurs wajib untuk akun non-rupiah: kurs hari transaksi tidak bisa
            // direkonstruksi belakangan, jadi harus ikut tercatat saat itu juga.
            'rate_idr' => [Rule::requiredIf($account->currency !== 'IDR'), 'nullable', 'numeric', 'gt:0'],
            'occurred_at' => ['required', 'date'],
            'proof' => [...$proof, Uploads::readable()],
            'note' => ['nullable', 'string', 'max:255'],
        ];
    }

    /** Bukti hanya keluar lewat route ini, setelah kepemilikan dicek. */
    public function proof(Transaction $transaction): StreamedResponse
    {
        abort_if(blank($transaction->proof_path), 404);

        return Storage::disk(Uploads::DISK)->response($transaction->proof_path);
    }

    /**
     * Tautan bukti yang tercetak di laporan. Tidak menyajikan berkasnya sendiri:
     * ia menerbitkan alamat pandang berumur pendek lalu melempar ke sana.
     *
     * Tautan ini sengaja tidak berbatas waktu. Yang memegang dokumen memang
     * berhak membukanya kapan pun, dan laporan pajak bisa saja baru dibaca
     * berbulan-bulan kemudian. Yang dibatasi umurnya adalah alamat hasil
     * lemparan — alamat itulah yang mendarat di riwayat browser dan gampang
     * tersalin ke mana-mana.
     *
     * Tidak dijaga sesi login: tanda tangan URL yang jadi izinnya, diperiksa
     * middleware `signed` sebelum sampai ke sini.
     */
    public function proofLink(string $proof): RedirectResponse
    {
        return redirect()->to(URL::temporarySignedRoute(
            'proofs.view',
            CarbonImmutable::now()->addSeconds(self::VIEW_SECONDS),
            ['proof' => $proof],
        ));
    }

    /**
     * Buktinya, disajikan di dalam halaman — bukan sebagai berkas gambar telanjang.
     * Kedaluwarsanya dijaga tanda tangan berbatas waktu milik Laravel, jadi tidak
     * ada jam yang perlu kami simpan dan cocokkan sendiri.
     *
     * Halaman itu mencegat klik kanan dan seret-keluar. Perlu jujur soal ini:
     * itu penghalang kosmetik, BUKAN pengaman. Ctrl+S, tab Network di DevTools,
     * dan screenshot tetap bisa mengambil gambarnya, dan memang tidak ada cara
     * mencegahnya — byte-nya sudah sampai di komputer yang menampilkannya.
     * Yang benar-benar menahan sebaran tetap dua hal lain: umur alamat ini yang
     * cuma 15 detik, dan tanda tangan yang tidak bisa dikarang.
     */
    public function proofView(string $proof): HttpResponse
    {
        $transaction = Transaction::findOrFail(Hashid::decode($proof));

        abort_if(blank($transaction->proof_path), 404);

        $disk = Storage::disk(Uploads::DISK);

        return response()->view('proofs.view', [
            'image' => 'data:'.($disk->mimeType($transaction->proof_path) ?: 'application/octet-stream')
                .';base64,'.base64_encode($disk->get($transaction->proof_path)),
        ]);
    }

    /** Umur alamat pandang, dihitung sejak tautan di dokumen diklik. */
    private const VIEW_SECONDS = 15;

    public function destroy(Transaction $transaction): RedirectResponse|JsonResponse
    {
        Uploads::delete($transaction->proof_path);
        $transaction->delete();

        return $this->done('Transaksi dihapus.');
    }
}
