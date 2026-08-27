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

    /** Kurva penuh dipakai berkali-kali per request (saldo, puncak, drawdown). */
    private ?array $curve = null;

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
        $points = $this->curve ??= $this->buildCurve();

        return ($from || $to)
            // Simpan titik terakhir sebelum rentang supaya garis tidak mulai dari nol.
            ? $this->clipToRange($points, $from, $to)
            : $points;
    }

    /** @return list<array{date: string, balance: float, pnl: float, flow: float}> */
    private function buildCurve(): array
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

        return $points;
    }

    /** @return list<array{month: string, pnl: float, profit: float, loss: float}> */
    public function monthlyPnl(int $months = 12): array
    {
        $start = CarbonImmutable::now()->startOfMonth()->subMonths($months - 1);

        // Dikelompokkan di PHP agar portabel antara MySQL & SQLite.
        $grouped = $this->closedTrades()
            ->whereRaw(self::TRADE_DATE.' >= ?', [$start])
            ->get(['pnl', 'closed_at', 'opened_at'])
            ->groupBy(fn (Trade $t) => ($t->closed_at ?? $t->opened_at)->format('Y-m'))
            ->map(fn (Collection $g) => [
                'pnl' => round((float) $g->sum('pnl'), 2),
                'profit' => round((float) $g->sum(fn (Trade $t) => max((float) $t->pnl, 0)), 2),
                'loss' => round((float) $g->sum(fn (Trade $t) => min((float) $t->pnl, 0)), 2),
            ]);

        $out = [];
        for ($i = 0; $i < $months; $i++) {
            $key = $start->addMonths($i)->format('Y-m');
            $out[] = ['month' => $key, ...($grouped[$key] ?? ['pnl' => 0.0, 'profit' => 0.0, 'loss' => 0.0])];
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
        $openingBalance = $this->openingBalances([$day->toDateString()])[$day->toDateString()];

        $lossLimit = $rule?->dailyLossLimit($openingBalance);
        $profitGoal = $rule?->dailyProfitGoal($openingBalance);
        $peak = $this->peakBalance();
        $drawdownPct = $peak > 0 ? round((1 - $this->latestBalance() / $peak) * 100, 2) : 0.0;

        // Trade yang stopnya sudah digeser ke BE/SL+ punya rr_planned null dan
        // memang tidak ikut dinilai — risiko awalnya tidak tercatat di mana pun.
        $lowRr = $rule?->min_rr === null
            ? 0
            : $today->filter(fn (Trade $t) => $t->rr_planned !== null && (float) $t->rr_planned < (float) $rule->min_rr)->count();

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
            'min_rr' => $rule?->min_rr === null ? null : (float) $rule->min_rr,
            'low_rr_trades' => $lowRr,
            'has_rules' => $rule !== null,
        ];
    }

    /**
     * Hari-hari di mana aturan dilanggar — dipakai untuk penanda kalender & AI.
     *
     * Semua aturan dinilai dari data yang sudah ada; tidak ada satu pun query
     * per hari di dalam loop. Aturan yang tidak diisi tidak menghabiskan apa pun.
     *
     * @return array<string, list<string>>
     */
    public function violations(CarbonInterface $from, CarbonInterface $to): array
    {
        $rule = $this->account->rule;

        if (! $rule) {
            return [];
        }

        $sessions = filled($rule->allowed_sessions) ? $rule->allowed_sessions : null;
        $riskPct = $rule->max_risk_per_trade_pct === null ? null : (float) $rule->max_risk_per_trade_pct;
        $perDay = $rule->max_daily_loss !== null || $rule->max_daily_loss_pct !== null || $rule->max_trades_per_day !== null;
        $perTrade = $rule->min_rr !== null || $sessions !== null || $riskPct !== null;

        if (! $perDay && ! $perTrade) {
            return [];
        }

        // Saldo pembukaan hanya perlu ditelusuri untuk aturan yang berbasis persen.
        $needsBalance = ($rule->max_daily_loss === null && $rule->max_daily_loss_pct !== null) || $riskPct !== null;
        $days = ($perDay || $needsBalance) ? $this->dailyPnl($from, $to) : [];
        $opening = $needsBalance ? $this->openingBalances(array_keys($days)) : [];

        $out = [];

        if ($perDay) {
            foreach ($days as $date => $day) {
                $limit = $rule->dailyLossLimit($opening[$date] ?? 0.0);

                if ($limit !== null && $day['pnl'] < 0 && abs($day['pnl']) > $limit) {
                    $out[$date][] = 'melewati batas loss harian';
                }
                if ($rule->max_trades_per_day !== null && $day['trades'] > $rule->max_trades_per_day) {
                    $out[$date][] = 'melebihi jumlah trade harian';
                }
            }
        }

        if ($perTrade) {
            $trades = $this->closedTrades()
                ->whereRaw(self::TRADE_DATE.' BETWEEN ? AND ?', [$from->copy()->startOfDay(), $to->copy()->endOfDay()])
                ->get(['pnl', 'rr_planned', 'opened_at', 'closed_at']);

            foreach ($trades as $trade) {
                $date = ($trade->closed_at ?? $trade->opened_at)->toDateString();

                if ($rule->min_rr !== null && $trade->rr_planned !== null && (float) $trade->rr_planned < (float) $rule->min_rr) {
                    $out[$date][] = 'RR di bawah minimum';
                }

                if ($sessions !== null && ! $this->inAnySession($trade->opened_at->hour, $sessions)) {
                    $out[$date][] = 'entry di luar sesi yang diizinkan';
                }

                // Risiko yang benar-benar terjadi: kerugian satu trade terhadap
                // saldo pembukaan hari itu. Yang direncanakan tidak pernah tercatat
                // dalam nilai uang, jadi ini satu-satunya angka yang jujur.
                $balance = $opening[$date] ?? 0.0;

                if ($riskPct !== null && $balance > 0 && (float) $trade->pnl < 0
                    && abs((float) $trade->pnl) > $balance * $riskPct / 100) {
                    $out[$date][] = 'rugi satu trade melewati batas risiko';
                }
            }
        }

        return array_map(fn (array $reasons) => array_values(array_unique($reasons)), $out);
    }

    /**
     * Rentang jam sesi pasar dalam WIB, [mulai, selesai). Nilai di atas 24 berarti
     * sesinya menyeberang tengah malam.
     *
     * ponytail: batasnya dipatok dan mengabaikan DST London/New York yang menggeser
     * sesi satu jam dua kali setahun. Kalau penandaannya nanti terasa meleset di
     * bulan peralihan, ganti dengan tabel per musim.
     */
    private const SESSIONS = [
        'sydney' => [4, 13],
        'tokyo' => [7, 16],
        'london' => [14, 23],
        'newyork' => [19, 28],
    ];

    /** @param  list<string>  $sessions */
    private function inAnySession(int $hour, array $sessions): bool
    {
        foreach ($sessions as $session) {
            [$start, $end] = self::SESSIONS[$session] ?? [0, 24];

            if (($hour >= $start && $hour < $end) || ($hour + 24 >= $start && $hour + 24 < $end)) {
                return true;
            }
        }

        return false;
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

    /** Saldo sekarang menurut kurva — sama dengan balance(), tanpa query tambahan. */
    private function latestBalance(): float
    {
        $curve = $this->equityCurve();

        return (float) end($curve)['balance'];
    }

    /**
     * Saldo pembukaan sejumlah tanggal sekaligus: saldo di titik kurva terakhir
     * sebelum hari itu. Satu kali telusur atas kurva yang urut kronologis, bukan
     * dua query per hari seperti balance().
     *
     * @param  list<string>  $dates
     * @return array<string, float>
     */
    private function openingBalances(array $dates): array
    {
        $curve = $this->equityCurve();
        sort($dates);

        $out = [];
        $at = 0;
        $balance = (float) $this->account->initial_balance;

        foreach ($dates as $date) {
            while ($at < count($curve) && $curve[$at]['date'] < $date) {
                $balance = $curve[$at]['balance'];
                $at++;
            }

            $out[$date] = $balance;
        }

        return $out;
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
