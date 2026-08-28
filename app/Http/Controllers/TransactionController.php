<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Services\AccountStats;
use App\Services\Uploads;
use Carbon\CarbonImmutable;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class TransactionController extends Controller
{
    private const FOLDER = 'proofs';

    public function index(Request $request): Response
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

        return Inertia::render('Transactions', [
            'filters' => ['year' => $year, 'month' => $month],
            'years' => range($newest, $oldest),
            'items' => $scoped()
                ->orderByDesc('occurred_at')
                ->orderByDesc('id')
                ->paginate(30)
                ->withQueryString()
                ->through(fn (Transaction $t) => [
                    ...$t->only('id', 'type', 'note'),
                    'amount' => (float) $t->amount,
                    'rate_idr' => $t->rate_idr === null ? null : (float) $t->rate_idr,
                    'occurred_at' => $t->occurred_at->toDateString(),
                    'has_proof' => filled($t->proof_path),
                ]),
            'totals' => [
                'deposit' => (float) ($flow['deposit']->total ?? 0),
                'withdrawal' => (float) ($flow['withdrawal']->total ?? 0),
                'deposit_idr' => (float) ($flow['deposit']->total_idr ?? 0) / $cents,
                'withdrawal_idr' => (float) ($flow['withdrawal']->total_idr ?? 0) / $cents,
                'balance' => $stats->balance(),
                'initial_balance' => (float) $account->initial_balance,
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $account = $request->currentAccount();

        $data = $request->validate([
            'type' => ['required', 'in:deposit,withdrawal'],
            'amount' => ['required', 'numeric', 'gt:0'],
            // Kurs wajib untuk akun non-rupiah: kurs hari transaksi tidak bisa
            // direkonstruksi belakangan, jadi harus ikut tercatat saat itu juga.
            'rate_idr' => [Rule::requiredIf($account->currency !== 'IDR'), 'nullable', 'numeric', 'gt:0'],
            'occurred_at' => ['required', 'date'],
            // Bukti transfer wajib — ini catatan uang sungguhan, bukan tebakan.
            'proof' => ['required', 'image', 'max:8192'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $data['proof_path'] = Uploads::store($request->file('proof'), $account, self::FOLDER);
        unset($data['proof']);

        $account->transactions()->create($data);

        return back()->with('success', $data['type'] === 'deposit' ? 'Deposit dicatat.' : 'Withdrawal dicatat.');
    }

    /** Bukti hanya keluar lewat route ini, setelah kepemilikan dicek. */
    public function proof(Transaction $transaction): StreamedResponse
    {
        abort_if(blank($transaction->proof_path), 404);

        return Storage::disk(Uploads::DISK)->response($transaction->proof_path);
    }

    public function destroy(Transaction $transaction): RedirectResponse
    {
        Uploads::delete($transaction->proof_path);
        $transaction->delete();

        return back()->with('success', 'Transaksi dihapus.');
    }
}
