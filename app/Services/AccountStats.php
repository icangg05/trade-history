<?php

namespace App\Services;

use App\Models\Account;
use App\Models\Trade;
use App\Models\Transaction;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;

/**
 * Semua agregasi akun dihitung di sini, langsung dari `trades` + `transactions`.
 * Tidak ada tabel snapshot saldo — untuk jurnal pribadi (ribuan baris) query
 * ulang jauh lebih murah daripada menjaga konsistensi tabel turunan.
 *
 * ponytail: full-scan per request. Kalau nanti puluhan ribu trade terasa lambat,
 * cache `equityCurve()` per akun dan invalidasi saat trade/transaksi berubah.
 */
class AccountStats
{
    /** Tanggal efektif sebuah trade = hari ia ditutup (fallback: hari dibuka). */
    private const TRADE_DATE = 'COALESCE(closed_at, opened_at)';

    public function __construct(private readonly Account $account) {}

    // ------------------------------------------------------------------ saldo

    public function balance(?CarbonInterface $upTo = null): float
    {
        return (float) $this->account->initial_balance
            + $this->netFlow($upTo)
            + $this->realisedPnl($upTo);
    }

    public function netFlow(?CarbonInterface $upTo = null): float
    {
        $rows = Transaction::query()
            ->where('account_id', $this->account->id)
            ->when($upTo, fn ($q) => $q->whereDate('occurred_at', '<=', $upTo))
            ->selectRaw('type, SUM(amount) as total')
            ->groupBy('type')
            ->pluck('total', 'type');

        return (float) ($rows['deposit'] ?? 0) - (float) ($rows['withdrawal'] ?? 0);
    }

    public function realisedPnl(?CarbonInterface $upTo = null): float
    {
        return (float) $this->closedTrades()
            ->when($upTo, fn ($q) => $q->whereRaw(self::TRADE_DATE.' <= ?', [$upTo->endOfDay()]))
            ->sum('pnl');
    }

    // ------------------------------------------------------------ kurva ekuitas

    /**
     * Titik saldo harian: hanya hari yang punya pergerakan, plus titik awal.
     *
     * @return list<array{date: string, balance: float, pnl: float, flow: float}>
     */
    public function equityCurve(?CarbonInterface $from = null, ?CarbonInterface $to = null): array
    {
        $pnlByDate = $this->closedTrades()
            ->selectRaw('DATE('.self::TRADE_DATE.') as d, SUM(pnl) as total')
            ->groupBy('d')
            ->pluck('total', 'd');

        $flowByDate = Transaction::query()
            ->where('account_id', $this->account->id)
            ->selectRaw("DATE(occurred_at) as d, SUM(CASE WHEN type = 'withdrawal' THEN -amount ELSE amount END) as total")
            ->groupBy('d')
            ->pluck('total', 'd');

        $dates = $pnlByDate->keys()->merge($flowByDate->keys())->unique()->sort()->values();

        $balance = (float) $this->account->initial_balance;
        $points = [[
            'date' => $this->account->started_at->toDateString(),
            'balance' => round($balance, 2),
            'pnl' => 0.0,
            'flow' => 0.0,
        ]];

        foreach ($dates as $date) {
            $pnl = (float) ($pnlByDate[$date] ?? 0);
            $flow = (float) ($flowByDate[$date] ?? 0);
            $balance += $pnl + $flow;

            $points[] = [
                'date' => $date,
                'balance' => round($balance, 2),
                'pnl' => round($pnl, 2),
                'flow' => round($flow, 2),
            ];
        }

        if ($from || $to) {
            // Simpan titik terakhir sebelum rentang supaya garis tidak mulai dari nol.
            $points = $this->clipToRange($points, $from, $to);
        }

        return $points;
    }

    /** @return list<array{month: string, pnl: float}> */
    public function monthlyPnl(int $months = 12): array
    {
        $start = CarbonImmutable::now()->startOfMonth()->subMonths($months - 1);

        // Dikelompokkan di PHP agar portabel antara MySQL & SQLite.
        $grouped = $this->closedTrades()
            ->whereRaw(self::TRADE_DATE.' >= ?', [$start])
            ->get(['pnl', 'closed_at', 'opened_at'])
            ->groupBy(fn (Trade $t) => ($t->closed_at ?? $t->opened_at)->format('Y-m'))
            ->map(fn (Collection $g) => round((float) $g->sum('pnl'), 2));

        $out = [];
        for ($i = 0; $i < $months; $i++) {
            $key = $start->addMonths($i)->format('Y-m');
            $out[] = ['month' => $key, 'pnl' => (float) ($grouped[$key] ?? 0)];
        }

        return $out;
    }

    // ---------------------------------------------------------------- kalender

    /**
     * P/L per hari untuk grid kalender.
     *
     * @return array<string, array{pnl: float, trades: int, wins: int, losses: int}>
     */
    public function dailyPnl(CarbonInterface $from, CarbonInterface $to): array
    {
        return $this->closedTrades()
            ->whereRaw(self::TRADE_DATE.' BETWEEN ? AND ?', [$from->copy()->startOfDay(), $to->copy()->endOfDay()])
            ->get(['pnl', 'status', 'closed_at', 'opened_at'])
            ->groupBy(fn (Trade $t) => ($t->closed_at ?? $t->opened_at)->toDateString())
            ->map(fn (Collection $g) => [
                'pnl' => round((float) $g->sum('pnl'), 2),
                'trades' => $g->count(),
                'wins' => $g->where('status', 'win')->count(),
                'losses' => $g->where('status', 'loss')->count(),
            ])
            ->all();
    }

    // ------------------------------------------------------------- status aturan

    /**
     * Posisi hari ini terhadap aturan akun. Murni informatif — tidak ada yang
     * diblokir, aplikasi ini cuma pengingat.
     */
    public function ruleStatus(?CarbonInterface $day = null): array
    {
        $day = CarbonImmutable::parse($day ?? now())->startOfDay();
        $rule = $this->account->rule;

        $today = $this->closedTrades()
            ->whereRaw('DATE('.self::TRADE_DATE.') = ?', [$day->toDateString()])
            ->get(['pnl', 'rr_planned']);

        $pnl = round((float) $today->sum('pnl'), 2);
        $openingBalance = $this->balance($day->subDay());

        $lossLimit = $rule?->dailyLossLimit($openingBalance);
        $profitGoal = $rule?->dailyProfitGoal($openingBalance);
        $peak = $this->peakBalance();
        $drawdownPct = $peak > 0 ? round((1 - $this->balance() / $peak) * 100, 2) : 0.0;

        return [
            'date' => $day->toDateString(),
            'pnl' => $pnl,
            'trades' => $today->count(),
            'opening_balance' => round($openingBalance, 2),
            'loss_limit' => $lossLimit ? round($lossLimit, 2) : null,
            'loss_used' => $pnl < 0 ? abs($pnl) : 0.0,
            'loss_breached' => $lossLimit !== null && $pnl < 0 && abs($pnl) >= $lossLimit,
            'profit_goal' => $profitGoal ? round($profitGoal, 2) : null,
            'profit_reached' => $profitGoal !== null && $pnl >= $profitGoal,
            'max_trades' => $rule?->max_trades_per_day,
            'trades_breached' => $rule?->max_trades_per_day !== null && $today->count() > $rule->max_trades_per_day,
            'drawdown_pct' => $drawdownPct,
            'max_drawdown_pct' => $rule?->max_total_loss_pct ? (float) $rule->max_total_loss_pct : null,
            'drawdown_breached' => $rule?->max_total_loss_pct !== null && $drawdownPct >= (float) $rule->max_total_loss_pct,
            'has_rules' => $rule !== null,
        ];
    }

    /** Hari-hari di mana aturan dilanggar — dipakai untuk penanda kalender & AI. */
    public function violations(CarbonInterface $from, CarbonInterface $to): array
    {
        $rule = $this->account->rule;

        if (! $rule) {
            return [];
        }

        $out = [];
        foreach ($this->dailyPnl($from, $to) as $date => $day) {
            $reasons = [];
            $limit = $rule->dailyLossLimit($this->balance(CarbonImmutable::parse($date)->subDay()));

            if ($limit !== null && $day['pnl'] < 0 && abs($day['pnl']) > $limit) {
                $reasons[] = 'melewati batas loss harian';
            }
            if ($rule->max_trades_per_day !== null && $day['trades'] > $rule->max_trades_per_day) {
                $reasons[] = 'melebihi jumlah trade harian';
            }
            if ($reasons) {
                $out[$date] = $reasons;
            }
        }

        if ($rule->min_rr !== null) {
            $lowRr = $this->closedTrades()
                ->whereRaw(self::TRADE_DATE.' BETWEEN ? AND ?', [$from->copy()->startOfDay(), $to->copy()->endOfDay()])
                ->whereNotNull('rr_planned')
                ->where('rr_planned', '<', $rule->min_rr)
                ->get(['closed_at', 'opened_at']);

            foreach ($lowRr as $trade) {
                $date = ($trade->closed_at ?? $trade->opened_at)->toDateString();
                $out[$date][] = 'RR di bawah minimum';
                $out[$date] = array_values(array_unique($out[$date]));
            }
        }

        return $out;
    }

    // ------------------------------------------------------------------ ringkasan

    /**
     * Statistik lengkap satu periode. Dipakai kartu dashboard dan dikirim
     * apa adanya ke Gemini untuk analisa (model tidak menghitung apa pun).
     */
    public function summary(CarbonInterface $from, CarbonInterface $to): array
    {
        $trades = $this->closedTrades()
            ->whereRaw(self::TRADE_DATE.' BETWEEN ? AND ?', [$from->copy()->startOfDay(), $to->copy()->endOfDay()])
            ->orderByRaw(self::TRADE_DATE)
            ->get();

        $wins = $trades->where('status', 'win');
        $losses = $trades->where('status', 'loss');
        $grossProfit = (float) $wins->sum('pnl');
        $grossLoss = abs((float) $losses->sum('pnl'));
        $count = $trades->count();

        $winRate = $count ? round($wins->count() / $count * 100, 1) : 0.0;
        $avgWin = $wins->count() ? round($grossProfit / $wins->count(), 2) : 0.0;
        $avgLoss = $losses->count() ? round($grossLoss / $losses->count(), 2) : 0.0;

        return [
            'period' => ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            'currency' => $this->account->currency,
            'initial_balance' => round((float) $this->account->initial_balance, 2),
            'balance' => round($this->balance(), 2),
            'net_flow' => round($this->netFlow(), 2),
            'total_trades' => $count,
            'open_trades' => (int) Trade::where('account_id', $this->account->id)->whereNull('pnl')->count(),
            'wins' => $wins->count(),
            'losses' => $losses->count(),
            'breakeven' => $trades->where('status', 'be')->count(),
            'win_rate_pct' => $winRate,
            'net_pnl' => round((float) $trades->sum('pnl'), 2),
            'gross_profit' => round($grossProfit, 2),
            'gross_loss' => round($grossLoss, 2),
            'profit_factor' => $grossLoss > 0 ? round($grossProfit / $grossLoss, 2) : null,
            'expectancy' => $count ? round((float) $trades->sum('pnl') / $count, 2) : 0.0,
            'avg_win' => $avgWin,
            'avg_loss' => $avgLoss,
            'payoff_ratio' => $avgLoss > 0 ? round($avgWin / $avgLoss, 2) : null,
            'largest_win' => round((float) ($trades->max('pnl') ?? 0), 2),
            'largest_loss' => round((float) ($trades->min('pnl') ?? 0), 2),
            'avg_rr_planned' => $this->avg($trades, 'rr_planned'),
            'avg_rr_realized' => $this->avg($trades, 'rr_realized'),
            'max_drawdown' => $this->maxDrawdown(),
            'longest_win_streak' => $this->streak($trades, 'win'),
            'longest_loss_streak' => $this->streak($trades, 'loss'),
            'by_symbol' => $this->breakdown($trades, fn (Trade $t) => $t->symbol),
            'by_direction' => $this->breakdown($trades, fn (Trade $t) => $t->direction),
            'by_weekday' => $this->breakdown($trades, fn (Trade $t) => ($t->closed_at ?? $t->opened_at)->isoFormat('dddd')),
            'by_hour' => $this->breakdown($trades, fn (Trade $t) => $t->opened_at->format('H').':00'),
            'by_setup' => $this->breakdown($trades, fn (Trade $t) => $t->setup
                ? array_filter(array_map('trim', explode(',', $t->setup)))
                : '(tanpa setup)'),
            'violations' => $this->violations($from, $to),
        ];
    }

    // ------------------------------------------------------------------ internal

    private function closedTrades()
    {
        return Trade::query()
            ->where('account_id', $this->account->id)
            ->whereNotNull('pnl');
    }

    private function peakBalance(): float
    {
        return collect($this->equityCurve())->max('balance') ?: (float) $this->account->initial_balance;
    }

    /** Penurunan terdalam dari puncak saldo, dalam mata uang & persen. */
    private function maxDrawdown(): array
    {
        $peak = null;
        $worst = 0.0;
        $worstPct = 0.0;

        foreach ($this->equityCurve() as $point) {
            $peak = $peak === null ? $point['balance'] : max($peak, $point['balance']);
            $drop = $peak - $point['balance'];

            if ($drop > $worst) {
                $worst = $drop;
                $worstPct = $peak > 0 ? $drop / $peak * 100 : 0.0;
            }
        }

        return ['amount' => round($worst, 2), 'pct' => round($worstPct, 2)];
    }

    private function avg(Collection $trades, string $field): ?float
    {
        $values = $trades->pluck($field)->filter(fn ($v) => $v !== null);

        return $values->isEmpty() ? null : round((float) $values->avg(), 2);
    }

    private function streak(Collection $trades, string $status): int
    {
        $best = $current = 0;

        foreach ($trades as $trade) {
            $current = $trade->status === $status ? $current + 1 : 0;
            $best = max($best, $current);
        }

        return $best;
    }

    private function breakdown(Collection $trades, callable $key): array
    {
        return $trades->groupBy($key)
            ->map(fn (Collection $g) => [
                'trades' => $g->count(),
                'pnl' => round((float) $g->sum('pnl'), 2),
                'win_rate_pct' => round($g->where('status', 'win')->count() / $g->count() * 100, 1),
            ])
            ->sortByDesc('trades')
            ->all();
    }

    private function clipToRange(array $points, ?CarbonInterface $from, ?CarbonInterface $to): array
    {
        $fromDate = $from?->toDateString();
        $toDate = $to?->toDateString();
        $out = [];
        $carry = null;

        foreach ($points as $point) {
            if ($toDate && $point['date'] > $toDate) {
                break;
            }
            if ($fromDate && $point['date'] < $fromDate) {
                $carry = ['date' => $fromDate, 'balance' => $point['balance'], 'pnl' => 0.0, 'flow' => 0.0];

                continue;
            }
            $out[] = $point;
        }

        // Titik bawaan hanya dipakai kalau rentang tidak sudah punya titik di hari itu.
        $needsCarry = $carry && (! $out || $out[0]['date'] !== $fromDate);

        return $needsCarry ? array_merge([$carry], $out) : $out;
    }
}
