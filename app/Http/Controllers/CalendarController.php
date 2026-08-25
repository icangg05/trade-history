<?php

namespace App\Http\Controllers;

use App\Models\Trade;
use App\Services\AccountStats;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class CalendarController extends Controller
{
    public function __invoke(Request $request): Response
    {
        $account = $request->currentAccount();
        $month = $this->month($request->string('month')->toString());
        $stats = new AccountStats($account);

        // Grid kalender ikut minggu penuh, jadi data diambil dari Senin sebelum
        // tanggal 1 sampai Minggu setelah tanggal terakhir.
        $gridStart = $month->startOfMonth()->startOfWeek(CarbonImmutable::MONDAY);
        $gridEnd = $month->endOfMonth()->endOfWeek(CarbonImmutable::SUNDAY);

        $trades = Trade::where('account_id', $account->id)
            ->whereNotNull('pnl')
            ->whereRaw('COALESCE(closed_at, opened_at) BETWEEN ? AND ?', [$gridStart, $gridEnd])
            ->orderBy('opened_at')
            ->get()
            ->groupBy(fn (Trade $t) => ($t->closed_at ?? $t->opened_at)->toDateString())
            ->map(fn ($group) => $group->map(fn (Trade $t) => [
                ...$t->only('id', 'symbol', 'direction', 'status', 'setup', 'group_id'),
                'stop_state' => $t->stopState(),
                'lot' => $t->lot === null ? null : (float) $t->lot,
                'pnl' => (float) $t->pnl,
                'rr_realized' => $t->rr_realized === null ? null : (float) $t->rr_realized,
                'opened_at' => $t->opened_at->toIso8601String(),
            ])->values());

        return Inertia::render('Calendar', [
            'month' => $month->format('Y-m'),
            'gridStart' => $gridStart->toDateString(),
            'gridEnd' => $gridEnd->toDateString(),
            'days' => $stats->dailyPnl($gridStart, $gridEnd),
            'violations' => $stats->violations($gridStart, $gridEnd),
            'trades' => $trades,
            'monthTotal' => $stats->dailyPnl($month->startOfMonth(), $month->endOfMonth()),
        ]);
    }

    private function month(string $value): CarbonImmutable
    {
        return preg_match('/^\d{4}-\d{2}$/', $value)
            ? CarbonImmutable::createFromFormat('Y-m-d', $value.'-01')->startOfDay()
            : CarbonImmutable::now()->startOfMonth();
    }
}
