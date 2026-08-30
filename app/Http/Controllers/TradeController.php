<?php

namespace App\Http\Controllers;

use App\Http\Requests\TradeRequest;
use App\Models\Trade;
use App\Services\Gemini;
use App\Support\Hashid;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Inertia\Inertia;
use Inertia\Response;

class TradeController extends Controller
{
    /** Sebuah trade dihitung di hari ia ditutup; yang masih terbuka di hari ia dibuka. */
    private const TRADE_DATE = 'COALESCE(closed_at, opened_at)';

    public function index(Request $request): Response
    {
        $account = $request->currentAccount();

        $filters = $request->validate([
            'symbol' => ['nullable', 'string', 'max:20'],
            'status' => ['nullable', 'in:win,loss,be'],
            'stop' => ['nullable', 'in:risk,breakeven,sl_plus'],
            'direction' => ['nullable', 'in:buy,sell'],
            'setup' => ['nullable', 'string', 'max:50'],
            'q' => ['nullable', 'string', 'max:60'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $query = $account->trades()
            ->when($filters['symbol'] ?? null, fn ($q, $v) => $q->where('symbol', strtoupper($v)))
            ->when($filters['status'] ?? null, fn ($q, $v) => $q->where('status', $v))
            // Posisi stop itu sumbu lain dari status hasil: trade bisa saja `win`
            // sekaligus SL+. Tidak disimpan sebagai kolom, jadi dibandingkan
            // langsung terhadap harga entry.
            ->when($filters['stop'] ?? null, fn ($q, $v) => match ($v) {
                'breakeven' => $q->whereColumn('sl_price', '=', 'entry_price'),
                'sl_plus' => $q->whereRaw("((direction = 'buy' AND sl_price > entry_price) OR (direction = 'sell' AND sl_price < entry_price))"),
                default => $q->whereRaw("((direction = 'buy' AND sl_price < entry_price) OR (direction = 'sell' AND sl_price > entry_price))"),
            })
            ->when($filters['direction'] ?? null, fn ($q, $v) => $q->where('direction', $v))
            // `setup` disimpan sebagai daftar dipisah koma, jadi cocokkan sebagian.
            ->when($filters['setup'] ?? null, fn ($q, $v) => $q->where('setup', 'like', '%'.self::escapeLike($v).'%'))
            ->when($filters['q'] ?? null, fn ($q, $v) => $q->where('notes', 'like', '%'.self::escapeLike($v).'%'))
            ->when($filters['from'] ?? null, fn ($q, $v) => $q->whereRaw(self::TRADE_DATE.' >= ?', [$v.' 00:00:00']))
            ->when($filters['to'] ?? null, fn ($q, $v) => $q->whereRaw(self::TRADE_DATE.' <= ?', [$v.' 23:59:59']));

        $trades = (clone $query)
            ->orderByRaw(self::TRADE_DATE.' DESC')
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (Trade $t) => $this->present($t));

        return Inertia::render('Trades/Index', [
            'trades' => $trades,
            'daily' => $this->dailyPnl($query, $trades->items()),
            'filters' => $filters,
            'symbols' => $account->trades()->distinct()->orderBy('symbol')->pluck('symbol'),
            // Strategi yang benar-benar dipakai akun ini, bukan daftar bawaan
            // SetupPicker — memfilter nama yang tidak pernah muncul tidak ada gunanya.
            'setups' => $account->trades()->whereNotNull('setup')->distinct()->pluck('setup')
                ->flatMap(fn (string $setup) => explode(',', $setup))
                ->map(fn (string $item) => trim($item))
                ->filter()
                ->unique()
                ->sort(SORT_NATURAL | SORT_FLAG_CASE)
                ->values(),
        ]);
    }

    /** `%` dan `_` di kata kunci adalah karakter biasa, bukan wildcard LIKE. */
    private static function escapeLike(string $value): string
    {
        return addcslashes($value, '%_\\');
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
            'ids.*' => ['string'],
        ]);

        $account = $request->currentAccount();
        $ids = array_map(Hashid::decode(...), $data['ids']);
        $trades = $account->trades()->whereIn('id', $ids)->orderByRaw(self::TRADE_DATE)->orderBy('id')->get();

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
    public function updateGroup(Request $request, string $group): RedirectResponse
    {
        $data = $request->validate([
            'setup' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ]);

        // `{group}` bukan model, jadi tidak lewat Route::bind — didekode di sini.
        // Kepemilikannya tetap terjaga: querynya dibatasi ke akun yang aktif.
        $members = $request->currentAccount()->trades()->where('group_id', Hashid::decode($group))->get();

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
            ->orderByRaw(self::TRADE_DATE)
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
        $order = $account->trades()->orderByRaw(self::TRADE_DATE)->orderBy('id')->pluck('id')->all();
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

    /**
     * P/L per hari untuk baris pembatas tanggal — dihitung di server supaya
     * tetap benar walau harinya terpotong batas halaman.
     *
     * @param  list<array<string, mixed>>  $page
     * @return array<string, float>
     */
    private function dailyPnl($query, array $page): array
    {
        $days = collect($page)->map(fn (array $t) => substr($t['closed_at'] ?? $t['opened_at'], 0, 10));

        if ($days->isEmpty()) {
            return [];
        }

        return (clone $query)
            ->whereRaw('DATE('.self::TRADE_DATE.') BETWEEN ? AND ?', [$days->min(), $days->max()])
            ->selectRaw('DATE('.self::TRADE_DATE.') as d, SUM(pnl) as total')
            ->groupBy('d')
            ->pluck('total', 'd')
            ->map(fn ($total) => round((float) $total, 2))
            ->all();
    }

    private function present(Trade $trade, bool $full = false): array
    {
        $base = [
            ...$trade->only('symbol', 'direction', 'status', 'setup', 'source', 'notes'),
            // Id tidak pernah keluar apa adanya — lihat App\Support\Hashid.
            'id' => $trade->getRouteKey(),
            'group_id' => $trade->group_id === null ? null : Hashid::encode($trade->group_id),
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
        ];

        return $full ? [...$base, 'ai_raw' => $trade->ai_raw] : $base;
    }

    private function num(mixed $value): ?float
    {
        return $value === null ? null : (float) $value;
    }
}
