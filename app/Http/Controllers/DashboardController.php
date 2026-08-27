<?php

namespace App\Http\Controllers;

use App\Services\AccountStats;
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
            ...$trade->only('id', 'symbol', 'direction', 'status', 'setup', 'group_id'),
            'stop_state' => $trade->stopState(),
            'pnl' => $trade->pnl === null ? null : (float) $trade->pnl,
            'rr_planned' => $trade->rr_planned === null ? null : (float) $trade->rr_planned,
            'opened_at' => $trade->opened_at->toIso8601String(),
        ];
    }
}
