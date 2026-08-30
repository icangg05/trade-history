<?php

namespace App\Http\Controllers;

use App\Services\AccountStats;
use App\Support\Hashid;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class DashboardController extends Controller
{
    /** Rentang cepat untuk kartu statistik & kurva ekuitas. */
    private const RANGES = ['30d' => 30, '90d' => 90, '1y' => 365];

    public function __invoke(Request $request): Response
    {
        $account = $request->currentAccount();
        $stats = new AccountStats($account);

        $range = $request->string('range')->toString() ?: '30d';
        $to = CarbonImmutable::now()->endOfDay();
        $from = $range === 'all'
            ? CarbonImmutable::parse($account->started_at)
            : $to->subDays(self::RANGES[$range] ?? 30)->startOfDay();

        return Inertia::render('Dashboard', [
            'range' => array_key_exists($range, self::RANGES) ? $range : ($range === 'all' ? 'all' : '30d'),
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
