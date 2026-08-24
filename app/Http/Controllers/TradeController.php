<?php

namespace App\Http\Controllers;

use App\Http\Requests\TradeRequest;
use App\Models\Trade;
use App\Services\Gemini;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class TradeController extends Controller
{
    public function index(Request $request): Response
    {
        $account = $request->currentAccount();

        $filters = $request->validate([
            'symbol' => ['nullable', 'string', 'max:20'],
            'status' => ['nullable', 'in:open,win,loss,be'],
            'direction' => ['nullable', 'in:buy,sell'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $trades = $account->trades()
            ->when($filters['symbol'] ?? null, fn ($q, $v) => $q->where('symbol', strtoupper($v)))
            ->when($filters['status'] ?? null, fn ($q, $v) => $q->where('status', $v))
            ->when($filters['direction'] ?? null, fn ($q, $v) => $q->where('direction', $v))
            ->when($filters['from'] ?? null, fn ($q, $v) => $q->whereRaw('COALESCE(closed_at, opened_at) >= ?', [$v.' 00:00:00']))
            ->when($filters['to'] ?? null, fn ($q, $v) => $q->whereRaw('COALESCE(closed_at, opened_at) <= ?', [$v.' 23:59:59']))
            ->orderByDesc('opened_at')
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (Trade $t) => $this->present($t));

        return Inertia::render('Trades/Index', [
            'trades' => $trades,
            'filters' => $filters,
            'symbols' => $account->trades()->distinct()->orderBy('symbol')->pluck('symbol'),
        ]);
    }

    public function create(): Response
    {
        return Inertia::render('Trades/Form', [
            'trade' => null,
            'aiEnabled' => app(Gemini::class)->configured(),
        ]);
    }

    public function store(TradeRequest $request): RedirectResponse
    {
        $account = $request->currentAccount();
        $data = $request->validated();
        $data['source'] ??= 'manual';

        $trade = $account->trades()->create($data);

        return redirect()
            ->route('trades.index')
            ->with('success', 'Trade '.$trade->symbol.' tersimpan.');
    }

    public function edit(Trade $trade): Response
    {
        return Inertia::render('Trades/Form', [
            'trade' => $this->present($trade, full: true),
            'aiEnabled' => app(Gemini::class)->configured(),
        ]);
    }

    public function update(TradeRequest $request, Trade $trade): RedirectResponse
    {
        $data = $request->validated();
        $data['source'] ??= $trade->source;

        $trade->update($data);

        return redirect()->route('trades.index')->with('success', 'Trade diperbarui.');
    }

    public function destroy(Trade $trade): RedirectResponse
    {
        $trade->delete();

        return back()->with('success', 'Trade dihapus.');
    }

    private function present(Trade $trade, bool $full = false): array
    {
        $base = [
            ...$trade->only('id', 'symbol', 'direction', 'status', 'setup', 'source', 'notes'),
            'lot' => $this->num($trade->lot),
            'entry_price' => $this->num($trade->entry_price),
            'sl_price' => $this->num($trade->sl_price),
            'tp_price' => $this->num($trade->tp_price),
            'exit_price' => $this->num($trade->exit_price),
            'pnl' => $this->num($trade->pnl),
            'stop_state' => $trade->stopState(),
            'rr_planned' => $this->num($trade->rr_planned),
            'rr_realized' => $this->num($trade->rr_realized),
            'opened_at' => $trade->opened_at->format('Y-m-d\TH:i'),
            'closed_at' => $trade->closed_at?->format('Y-m-d\TH:i'),
            'tags' => $trade->tags ?? [],
        ];

        return $full ? [...$base, 'ai_raw' => $trade->ai_raw] : $base;
    }

    private function num(mixed $value): ?float
    {
        return $value === null ? null : (float) $value;
    }
}
