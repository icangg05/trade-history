<?php

namespace App\Http\Controllers;

use App\Models\Account;
use App\Services\AccountStats;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class AccountController extends Controller
{
    public function index(Request $request): Response
    {
        $accounts = $request->user()->accounts()->orderBy('is_archived')->orderBy('name')->get()
            ->map(function (Account $account) {
                $stats = new AccountStats($account);

                return [
                    ...$account->only('id', 'name', 'broker', 'currency', 'is_archived'),
                    'initial_balance' => (float) $account->initial_balance,
                    'started_at' => $account->started_at->toDateString(),
                    'balance' => $stats->balance(),
                    'net_pnl' => $stats->realisedPnl(),
                    'trades' => $account->trades()->count(),
                ];
            });

        return Inertia::render('Accounts', [
            'items' => $accounts,
            'activeId' => $request->currentAccount()?->id,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $account = $request->user()->accounts()->create($this->validated($request));

        $request->session()->put('current_account_id', $account->id);

        return redirect()->route('dashboard')->with('success', 'Akun "'.$account->name.'" dibuat.');
    }

    public function update(Request $request, Account $account): RedirectResponse
    {
        $account->update($this->validated($request));

        return back()->with('success', 'Akun diperbarui.');
    }

    public function destroy(Request $request, Account $account): RedirectResponse
    {
        $account->delete();

        if ($request->session()->get('current_account_id') === $account->id) {
            $request->session()->forget('current_account_id');
        }

        return redirect()->route('accounts.index')->with('success', 'Akun dihapus beserta seluruh riwayatnya.');
    }

    public function switch(Request $request, Account $account): RedirectResponse
    {
        $request->session()->put('current_account_id', $account->id);

        return redirect()->route('dashboard');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'broker' => ['nullable', 'string', 'max:60'],
            'currency' => ['required', 'in:USD,USC,IDR'],
            'initial_balance' => ['required', 'numeric', 'min:0'],
            'started_at' => ['required', 'date'],
            'is_archived' => ['nullable', 'boolean'],
        ]);
    }
}
