<?php

namespace App\Http\Controllers;

use App\Services\AccountStats;
use App\Support\Hashid;
use App\Support\Period;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Inertia\Response;

class DashboardController extends Controller
{
    public function __invoke(Request $request): Response|JsonResponse
    {
        $account = $request->currentAccount();
        $stats = new AccountStats($account);

        [$from, $to, $range] = Period::resolve($account, $request->string('range')->toString());

        return $this->page('Dashboard', [
            'range' => $range,
            'summary' => $stats->summary($from, $to),
            'equity' => $stats->equityCurve($from, $to),
            'monthly' => $stats->monthlyPnl(12),
            // Dasar persentase grafik bulanan: saldo tepat sebelum jendela 12
            // bulannya dimulai. Bukan `modal awal + arus kas` — withdrawal
            // mengecilkan angka itu, jadi menarik dana bikin persennya naik
            // padahal hasil tradingnya sama saja.
            'monthlyBase' => $stats->balance(CarbonImmutable::now()->startOfMonth()->subMonths(11)->subDay()),
            'ruleStatus' => $stats->ruleStatus(),
            'recent' => $account->trades()
                // Urutan yang sama dengan /trades dan kalender: hari trade ditutup.
                ->orderByRaw('COALESCE(closed_at, opened_at) DESC')
                ->orderByDesc('id')
                ->limit(10)
                ->get()
                ->map(fn ($t) => $this->row($t)),
        ]);
    }

    private function row($trade): array
    {
        return [
            ...$trade->only('symbol', 'direction', 'status', 'setup'),
            'id' => $trade->getRouteKey(),
            'group_id' => $trade->group_id === null ? null : Hashid::encode($trade->group_id),
            'stop_state' => $trade->stopState(),
            'pnl' => (float) $trade->pnl,
            'rr_planned' => $trade->rr_planned === null ? null : (float) $trade->rr_planned,
            'opened_at' => $trade->opened_at->toIso8601String(),
        ];
    }
}
