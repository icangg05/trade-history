<?php

namespace App\Http\Controllers;

use App\Models\Account;
use App\Services\AccountStats;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Response;

class AccountController extends Controller
{
    public function index(Request $request): Response|JsonResponse
    {
        $accounts = $request->user()->accounts()->orderBy('is_archived')->orderBy('name')->get()
            ->map(function (Account $account) {
                $stats = new AccountStats($account);

                return [
                    ...$account->only('id', 'name', 'broker', 'account_number', 'currency', 'is_archived'),
                    'started_at' => $account->started_at->toDateString(),
                    'balance' => $stats->balance(),
                    'net_pnl' => $stats->realisedPnl(),
                    'trades' => $account->trades()->count(),
                ];
            });

        return $this->page('Accounts', [
            'items' => $accounts,
            // Satu-satunya tempat yang menjumlahkan seluruh akun: layar lain
            // selalu mengikuti akun aktif. Dikelompokkan per mata uang, karena
            // USD, USC (akun sen), dan IDR bukan satuan yang sama — laporan
            // pajaklah yang mengubah semuanya jadi rupiah, dengan kurs yang
            // diisi sendiri dan tanggal berlakunya.
            'totals' => $accounts->groupBy('currency')
                ->map(fn ($rows, $currency) => [
                    'currency' => $currency,
                    'accounts' => $rows->count(),
                    'balance' => round($rows->sum('balance'), 2),
                    'net_pnl' => round($rows->sum('net_pnl'), 2),
                    'trades' => $rows->sum('trades'),
                ])
                ->sortKeys()
                ->values(),
            'activeId' => $request->currentAccount()?->id,
        ]);
    }

    public function store(Request $request): RedirectResponse|JsonResponse
    {
        $account = $request->user()->accounts()->create($this->validated($request));

        // Aplikasi mobile tidak punya sesi: akun yang dibuka ikut di alamatnya,
        // jadi yang perlu ia tahu cukup id akun barunya.
        if ($request->hasSession()) {
            $request->session()->put('current_account_id', $account->id);
        }

        return $this->done(
            'Akun "'.$account->name.'" dibuat.',
            data: ['id' => $account->id],
            status: 201,
        );
    }

    public function update(Request $request, Account $account): RedirectResponse|JsonResponse
    {
        $account->update($this->validated($request));

        return $this->done('Akun diperbarui.');
    }

    public function destroy(Request $request, Account $account): RedirectResponse|JsonResponse
    {
        $account->delete();

        if ($request->hasSession() && $request->session()->get('current_account_id') === $account->id) {
            $request->session()->forget('current_account_id');
        }

        return $this->done('Akun dihapus beserta seluruh riwayatnya.');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'broker' => ['nullable', 'string', 'max:60'],
            'account_number' => ['nullable', 'string', 'max:40'],
            'currency' => ['required', 'in:USD,USC,IDR'],
            'started_at' => ['required', 'date'],
            'is_archived' => ['nullable', 'boolean'],
        ]);
    }
}
