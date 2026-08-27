<?php

namespace App\Http\Controllers;

use App\Services\AccountStats;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Aturan trading di sini murni catatan pribadi + indikator. Tidak ada satu pun
 * nilai di halaman ini yang memblokir pencatatan trade.
 */
class RuleController extends Controller
{
    public function edit(Request $request): Response
    {
        $account = $request->currentAccount();
        $rule = $account->rule;
        $stats = new AccountStats($account);

        return Inertia::render('Rules', [
            'rule' => [
                'max_daily_loss' => $this->num($rule?->max_daily_loss),
                'max_daily_loss_pct' => $this->num($rule?->max_daily_loss_pct),
                'daily_profit_target' => $this->num($rule?->daily_profit_target),
                'daily_profit_target_pct' => $this->num($rule?->daily_profit_target_pct),
                'max_total_loss_pct' => $this->num($rule?->max_total_loss_pct),
                'max_risk_per_trade_pct' => $this->num($rule?->max_risk_per_trade_pct),
                'max_trades_per_day' => $rule?->max_trades_per_day,
                'min_rr' => $this->num($rule?->min_rr),
                'allowed_sessions' => $rule?->allowed_sessions ?? [],
                'notes' => $rule?->notes ?? '',
            ],
            'status' => $stats->ruleStatus(),

            // Dasar perkiraan untuk aturan yang diisi dalam persen: modal awal
            // ditambah dana yang masuk dan keluar, tanpa hasil trading. Angka
            // yang dipakai saat menilai pelanggaran tetap saldo pembukaan hari
            // itu, jadi ini memang perkiraan.
            'basis' => round((float) $account->initial_balance + $stats->netFlow(), 2),
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'max_daily_loss' => ['nullable', 'numeric', 'gt:0'],
            'max_daily_loss_pct' => ['nullable', 'numeric', 'gt:0', 'max:100'],
            'daily_profit_target' => ['nullable', 'numeric', 'gt:0'],
            'daily_profit_target_pct' => ['nullable', 'numeric', 'gt:0', 'max:100'],
            'max_total_loss_pct' => ['nullable', 'numeric', 'gt:0', 'max:100'],
            'max_risk_per_trade_pct' => ['nullable', 'numeric', 'gt:0', 'max:100'],
            'max_trades_per_day' => ['nullable', 'integer', 'min:1', 'max:255'],
            'min_rr' => ['nullable', 'numeric', 'gt:0', 'max:99'],
            'allowed_sessions' => ['nullable', 'array'],
            'allowed_sessions.*' => ['string', 'in:sydney,tokyo,london,newyork'],
            'notes' => ['nullable', 'string', 'max:20000'],
        ]);

        $request->currentAccount()->rule()->updateOrCreate([], $data);

        return back()->with('success', 'Aturan tersimpan.');
    }

    private function num(mixed $value): ?float
    {
        return $value === null ? null : (float) $value;
    }
}
