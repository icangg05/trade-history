<?php

namespace App\Http\Controllers;

use App\Http\Requests\TradeRequest;
use App\Models\Trade;
use App\Services\Gemini;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
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

        // Setup dan catatan milik grup, bukan milik satu trade. Form sudah
        // mengunci fieldnya; ini penjaga terakhirnya.
        if ($trade->group_id !== null) {
            unset($data['setup'], $data['notes']);
        }

        $trade->update($data);

        return redirect()->route('trades.index')->with('success', 'Trade diperbarui.');
    }

    public function destroy(Trade $trade): RedirectResponse
    {
        $trade->delete();

        return back()->with('success', 'Trade dihapus.');
    }

    /**
     * Tandai beberapa trade berurutan sebagai satu ide yang sama. Tidak ada
     * baris yang hilang dan tidak ada nama grup: kuncinya id trade paling awal.
     * Setup dan catatan anggotanya digabung, lalu dikelola lewat grup.
     */
    public function group(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:2', 'max:50'],
            'ids.*' => ['integer'],
        ]);

        $account = $request->currentAccount();
        $trades = $account->trades()->whereIn('id', $data['ids'])->orderBy('opened_at')->orderBy('id')->get();

        if ($trades->count() !== count($data['ids'])) {
            return back()->with('error', 'Ada trade yang tidak ditemukan di akun ini.');
        }

        // Pilihan boleh menyentuh satu grup yang sudah ada — itu cara menambah
        // anggota baru ke dalamnya. Dua grup sekaligus tidak: pindah grup harus
        // lewat dikeluarkan dulu.
        $existing = $trades->pluck('group_id')->filter()->unique();

        if ($existing->count() > 1) {
            return back()->with('error', 'Pilihannya menyentuh dua grup — keluarkan dulu salah satunya.');
        }

        if (! $this->adjacent($account, $trades->pluck('id')->all())) {
            return back()->with('error', 'Hanya trade yang berurutan yang bisa digabung jadi satu grup.');
        }

        $groupId = (int) ($existing->first() ?? $trades->first()->id);
        $setup = $this->unionSetup($trades);
        $notes = $this->unionNotes($trades);

        foreach ($trades as $trade) {
            $data = [
                'group_id' => $groupId,
                'setup' => $setup ?? $trade->setup,
                'notes' => $notes ?? $trade->notes,
            ];

            // Setup & catatan aslinya disimpan sekali, saat trade pertama kali
            // masuk grup — itu yang dikembalikan kalau nanti dikeluarkan.
            if ($trade->group_id === null) {
                $data['pre_group'] = ['setup' => $trade->setup, 'notes' => $trade->notes];
            }

            $trade->update($data);
        }

        return back()->with('success', $trades->count().' trade jadi satu grup.');
    }

    /** Setup dan catatan grup: satu form untuk semua anggotanya. */
    public function updateGroup(Request $request, int $group): RedirectResponse
    {
        $data = $request->validate([
            'setup' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ]);

        $members = $request->currentAccount()->trades()->where('group_id', $group)->get();

        if ($members->isEmpty()) {
            return back()->with('error', 'Grup tidak ditemukan.');
        }

        foreach ($members as $trade) {
            $trade->update($data);
        }

        return back()->with('success', 'Grup diperbarui.');
    }

    /**
     * Keluarkan satu trade dari grupnya, hanya dari ujung atas atau bawah.
     * Melepas yang di tengah akan meninggalkan grup yang anggotanya terpisah —
     * tidak lagi berurutan, dan bingkainya jadi bohong.
     *
     * Grup yang tinggal satu anggota bukan grup lagi, jadi sisanya ikut dilepas.
     */
    public function ungroup(Request $request, Trade $trade): RedirectResponse
    {
        $group = $trade->group_id;

        if ($group === null) {
            return back();
        }

        $members = $request->currentAccount()
            ->trades()
            ->where('group_id', $group)
            ->orderBy('opened_at')
            ->orderBy('id')
            ->get();

        if ($members->first()->id !== $trade->id && $members->last()->id !== $trade->id) {
            return back()->with('error', 'Hanya trade di ujung grup yang bisa dikeluarkan.');
        }

        $this->release($trade);

        $left = $members->reject(fn (Trade $t) => $t->id === $trade->id);

        if ($left->count() < 2) {
            $left->each(fn (Trade $t) => $this->release($t));
        }

        return back()->with('success', 'Trade dikeluarkan dari grup.');
    }

    /** Lepas dari grup: setup & catatan sebelum bergrup dipulihkan. */
    private function release(Trade $trade): void
    {
        $before = $trade->pre_group ?? [];

        $trade->update([
            'group_id' => null,
            'pre_group' => null,
            'setup' => $before['setup'] ?? $trade->setup,
            'notes' => $before['notes'] ?? $trade->notes,
        ]);
    }

    /**
     * Benar hanya bila id-id itu berurutan tanpa sela di riwayat akun.
     *
     * ponytail: membandingkan posisi di daftar id akun — cukup sampai puluhan
     * ribu trade; kalau lebih, ganti dengan query rentang waktu.
     *
     * @param  list<int>  $ids
     */
    private function adjacent($account, array $ids): bool
    {
        $order = $account->trades()->orderBy('opened_at')->orderBy('id')->pluck('id')->all();
        $positions = array_keys(array_intersect($order, $ids));

        return count($positions) === count($ids)
            && max($positions) - min($positions) + 1 === count($ids);
    }

    /** Semua strategi yang dipakai anggota grup, tercentang di tiap trade. */
    private function unionSetup(Collection $trades): ?string
    {
        $list = $trades->pluck('setup')
            ->flatMap(fn (?string $setup) => explode(',', (string) $setup))
            ->map(fn (string $item) => trim($item))
            ->filter()
            ->unique();

        return $list->isEmpty() ? null : mb_substr($list->implode(', '), 0, 255);
    }

    /** Catatan anggota grup disambung jadi satu paragraf, tanpa yang kembar. */
    private function unionNotes(Collection $trades): ?string
    {
        $notes = $trades->pluck('notes')
            ->map(fn (?string $note) => trim((string) $note))
            ->filter()
            ->unique()
            ->map(fn (string $note) => str_ends_with($note, '.') || str_ends_with($note, '!') || str_ends_with($note, '?')
                ? $note
                : $note.'.');

        return $notes->isEmpty() ? null : mb_substr($notes->implode(' '), 0, 5000);
    }

    private function present(Trade $trade, bool $full = false): array
    {
        $base = [
            ...$trade->only('id', 'symbol', 'direction', 'status', 'setup', 'group_id', 'source', 'notes'),
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
