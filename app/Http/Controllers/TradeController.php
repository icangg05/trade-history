<?php

namespace App\Http\Controllers;

use App\Http\Requests\TradeRequest;
use App\Models\Trade;
use App\Services\Gemini;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
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

    /**
     * Gabungkan beberapa trade yang sebenarnya satu ide berlapis menjadi satu
     * trade berlayer. Trade asalnya dihapus — ini jalan satu arah, jadi UI-nya
     * memakai konfirmasi berkode.
     */
    public function merge(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:2', 'max:20'],
            'ids.*' => ['integer'],
        ]);

        // Diambil lewat relasi akun aktif: id milik akun lain tidak akan ikut,
        // dan selisih jumlahnya sudah cukup jadi penolakan.
        $trades = $request->currentAccount()
            ->trades()
            ->whereIn('id', $data['ids'])
            ->orderBy('opened_at')
            ->orderBy('id')
            ->get();

        if ($trades->count() !== count($data['ids'])) {
            return back()->with('error', 'Ada trade yang tidak ditemukan di akun ini.');
        }

        if ($trades->pluck('symbol')->unique()->count() > 1 || $trades->pluck('direction')->unique()->count() > 1) {
            return back()->with('error', 'Hanya trade dengan simbol dan arah yang sama bisa digabung.');
        }

        if ($trades->contains(fn (Trade $t) => $t->lot === null)) {
            return back()->with('error', 'Semua trade harus punya lot — entry rata-rata dihitung dari lot.');
        }

        $closed = $trades->filter(fn (Trade $t) => $t->isClosed());

        if ($closed->isNotEmpty() && $closed->count() !== $trades->count()) {
            return back()->with('error', 'Jangan campur posisi terbuka dengan yang sudah tertutup.');
        }

        $first = $trades->first();
        $exitLots = $trades->filter(fn (Trade $t) => $t->exit_price !== null);
        $exitWeight = (float) $exitLots->sum('lot');
        $account = $request->currentAccount();

        $merged = DB::transaction(function () use ($account, $trades, $first, $closed, $exitLots, $exitWeight) {
            $trade = $account->trades()->create([
                'symbol' => $first->symbol,
                'direction' => $first->direction,
                'entries' => $trades->flatMap(fn (Trade $t) => $t->layers())->all(),
                'sl_price' => $first->sl_price,
                'tp_price' => $first->tp_price,
                'exit_price' => $exitWeight > 0
                    ? round($exitLots->sum(fn (Trade $t) => (float) $t->exit_price * (float) $t->lot) / $exitWeight, 5)
                    : null,
                'pnl' => $closed->isEmpty() ? null : round((float) $closed->sum('pnl'), 2),
                'opened_at' => $trades->min('opened_at'),
                'closed_at' => $closed->isEmpty() ? null : $closed->max('closed_at'),
                'setup' => $this->mergedSetup($trades),
                'tags' => $trades->flatMap(fn (Trade $t) => $t->tags ?? [])->unique()->values()->all(),
                'notes' => $this->mergedNotes($trades),
                'source' => $trades->every(fn (Trade $t) => $t->source === 'ai') ? 'ai' : 'manual',
            ]);

            Trade::whereIn('id', $trades->pluck('id'))->delete();

            return $trade;
        });

        return redirect()
            ->route('trades.index')
            ->with('success', $trades->count().' trade digabung jadi satu '.$merged->symbol.' berlayer.');
    }

    /** @param Collection<int, Trade> $trades */
    private function mergedSetup(Collection $trades): ?string
    {
        $list = $trades->pluck('setup')
            ->flatMap(fn (?string $setup) => explode(',', (string) $setup))
            ->map(fn (string $item) => trim($item))
            ->filter()
            ->unique();

        // Kolomnya 255 karakter; gabungan dari banyak trade bisa lewat.
        return $list->isEmpty() ? null : mb_substr($list->implode(', '), 0, 255);
    }

    /** @param Collection<int, Trade> $trades */
    private function mergedNotes(Collection $trades): ?string
    {
        $notes = $trades->pluck('notes')->filter();

        return $notes->isEmpty() ? null : mb_substr($notes->implode("\n\n---\n\n"), 0, 5000);
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
            'entries' => $trade->entries ?? [],
        ];

        return $full ? [...$base, 'ai_raw' => $trade->ai_raw] : $base;
    }

    private function num(mixed $value): ?float
    {
        return $value === null ? null : (float) $value;
    }
}
