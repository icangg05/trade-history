<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Services\AccountStats;
use App\Services\Uploads;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
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

        return Inertia::render('Transactions', [
            'items' => $account->transactions()
                ->orderByDesc('occurred_at')
                ->orderByDesc('id')
                ->paginate(30)
                ->through(fn (Transaction $t) => [
                    ...$t->only('id', 'type', 'note'),
                    'amount' => (float) $t->amount,
                    'occurred_at' => $t->occurred_at->toDateString(),
                    'has_proof' => filled($t->proof_path),
                ]),
            'totals' => [
                'deposit' => (float) $account->transactions()->where('type', 'deposit')->sum('amount'),
                'withdrawal' => (float) $account->transactions()->where('type', 'withdrawal')->sum('amount'),
                'balance' => $stats->balance(),
                'initial_balance' => (float) $account->initial_balance,
                'realised_pnl' => $stats->realisedPnl(),
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:deposit,withdrawal'],
            'amount' => ['required', 'numeric', 'gt:0'],
            'occurred_at' => ['required', 'date'],
            // Bukti transfer wajib — ini catatan uang sungguhan, bukan tebakan.
            'proof' => ['required', 'image', 'max:8192'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $account = $request->currentAccount();
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
