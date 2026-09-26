<?php

namespace App\Http\Controllers;

use App\Models\Account;
use App\Models\AiAnalysis;
use App\Services\AccountStats;
use App\Services\Gemini;
use App\Support\Period;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Response;
use RuntimeException;

class AnalysisController extends Controller
{
    public function index(Request $request, Gemini $gemini): Response|JsonResponse
    {
        $account = $request->currentAccount();
        [$from, $to, $period] = $this->period($request);

        $calc = new AccountStats($account);
        $stats = $calc->summary($from, $to);
        $hash = $this->hash($stats);

        // Cocok persis dulu; kalau statistik sudah berubah, analisa terakhir
        // tetap ditampilkan (ditandai usang) supaya bacaannya tidak hilang
        // begitu satu trade baru masuk.
        $saved = AiAnalysis::where('account_id', $account->id)->latest();
        $analysis = (clone $saved)->where('stats_hash', $hash)->first() ?? $saved->first();

        return $this->page('Analysis', [
            'period' => $period,
            'summary' => $stats,
            // Pembanding di kartu angka: membaik atau memburuk dari periode
            // sepanjang ini tepat sebelumnya.
            'previous' => $this->previous($calc, $from, $period),
            'aiEnabled' => $gemini->configured(),
            'model' => $gemini->model(),
            'analysis' => $analysis ? [
                ...$analysis->only('result_md', 'model'),
                // Baris ini hanya ditulis saat AI benar-benar dipanggil, jadi
                // updated_at = kapan terakhir dianalisa (created_at tidak bergerak
                // saat hasil lama ditimpa).
                'analyzed_at' => $analysis->updated_at,
                'period_start' => $analysis->period_start->toDateString(),
                'period_end' => $analysis->period_end->toDateString(),
                'stale' => $analysis->stats_hash !== $hash,
            ] : null,
        ]);
    }

    public function generate(Request $request, Gemini $gemini): RedirectResponse|JsonResponse
    {
        $account = $request->currentAccount();
        [$from, $to, $period] = $this->period($request);

        $calc = new AccountStats($account);
        $stats = $calc->summary($from, $to);

        if ($stats['total_trades'] === 0) {
            return $this->failed('Belum ada trade tertutup di periode ini.');
        }

        // Tombol ini selalu memanggil Gemini: diam-diam memakai ulang hasil lama
        // terbaca seperti tombol rusak. Pemborosannya ditahan di tempat lain —
        // jeda 10 detik per kunci (GeminiKey::COOLDOWN) dan throttle rute.
        try {
            $markdown = $gemini->analyze($this->context($account, $calc, $stats, $from, $to, $period));
        } catch (RuntimeException $e) {
            return $this->failed($e->getMessage(), 502);
        }

        AiAnalysis::updateOrCreate(
            ['account_id' => $account->id, 'stats_hash' => $this->hash($stats)],
            [
                'period_start' => $from->toDateString(),
                'period_end' => $to->toDateString(),
                'result_md' => $markdown,
                'model' => $gemini->model(),
            ],
        )->touch();

        return $this->done('Analisa selesai.');
    }

    /** Layar chat penuh, terpisah dari halaman analisa supaya muat sampai ujung. */
    public function chatPage(Request $request, Gemini $gemini): Response|JsonResponse
    {
        [, , $period] = $this->period($request);

        return $this->page('Analysis/Chat', [
            'period' => $period,
            'aiEnabled' => $gemini->configured(),
        ]);
    }

    /**
     * Tanya jawab dengan AI soal akun ini.
     *
     * JSON, bukan Inertia: percakapan hanya hidup di layar dan tidak disimpan,
     * jadi tidak ada yang perlu dikirim ulang sebagai props halaman.
     * ponytail: simpan ke tabel kalau riwayat chat mulai dibutuhkan lintas sesi.
     */
    public function chat(Request $request, Gemini $gemini): JsonResponse
    {
        if (! $gemini->configured()) {
            return response()->json(['error' => 'Kunci Gemini belum ditambahkan admin.'], 503);
        }

        $data = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
            'history' => ['array', 'max:20'],
            'history.*.role' => ['required', 'in:user,assistant'],
            'history.*.text' => ['required', 'string', 'max:8000'],
        ]);

        $account = $request->currentAccount();
        [$from, $to, $period] = $this->period($request);

        $calc = new AccountStats($account);
        $stats = $calc->summary($from, $to);

        if ($stats['total_trades'] === 0) {
            return response()->json(['error' => 'Belum ada trade di periode ini untuk dibahas.'], 422);
        }

        // Pertanyaan baru selalu ditempel di ujung: urutan giliran ditentukan di
        // sini, bukan dipercayakan pada apa yang dikirim browser.
        $messages = [...($data['history'] ?? []), ['role' => 'user', 'text' => $data['message']]];

        try {
            $reply = $gemini->chat($this->context($account, $calc, $stats, $from, $to, $period), $messages);
        } catch (RuntimeException $e) {
            return response()->json(['error' => $e->getMessage()], 502);
        }

        return response()->json(['reply' => $reply]);
    }

    /**
     * Bahan untuk AI. Statistik saja hanya bisa dirangkum; yang membuat
     * analisa berguna adalah pembanding: pola perilaku di balik angka, periode
     * sebelumnya (membaik atau memburuk), aturan yang sedang dipasang (supaya
     * sarannya bisa langsung diisi di halaman Aturan), dan rencana analisa
     * terakhir beserta hasil trade sejak itu (dijalankan atau tidak).
     */
    private function context(
        Account $account,
        AccountStats $calc,
        array $stats,
        CarbonImmutable $from,
        CarbonImmutable $to,
        string $period,
    ): array {
        $rule = $account->rule;

        return [
            'statistik' => $stats,
            'perilaku' => $calc->behavior($from, $to),
            'periode_sebelumnya' => $this->previous($calc, $from, $period),
            'aturan_terpasang' => $rule ? array_filter(
                $rule->only([
                    'max_daily_loss', 'max_daily_loss_pct', 'daily_profit_target', 'daily_profit_target_pct',
                    'max_total_loss', 'max_total_loss_pct', 'max_risk_per_trade', 'max_risk_per_trade_pct',
                    'max_trades_per_day', 'min_rr', 'allowed_sessions', 'notes',
                ]),
                fn ($value) => filled($value),
            ) : null,
            'rencana_sebelumnya' => $this->lastPlan($account, $calc, $to),
        ];
    }

    /** Angka inti periode sepanjang ini tepat sebelumnya; null kalau kosong. */
    private function previous(AccountStats $calc, CarbonImmutable $from, string $period): ?array
    {
        $range = Period::previous($from, $period);

        if ($range === null) {
            return null;
        }

        $stats = $calc->summary(...$range);

        return $stats['total_trades'] === 0 ? null : [
            'period' => $stats['period'],
            ...array_intersect_key($stats, array_flip([
                'total_trades', 'win_rate_pct', 'net_pnl', 'profit_factor', 'expectancy',
                'avg_win', 'avg_loss', 'payoff_ratio', 'largest_loss', 'longest_loss_streak',
            ])),
        ];
    }

    /**
     * Bagian rencana dari analisa terakhir, dan hasil trade sejak ditulis.
     * Rencana yang umurnya belum sehari belum bisa dinilai — itu hasil tombol
     * Perbarui atas data yang sama, bukan rencana yang sudah dijalankan.
     */
    private function lastPlan(Account $account, AccountStats $calc, CarbonImmutable $to): ?array
    {
        $last = AiAnalysis::where('account_id', $account->id)->latest('updated_at')->first();

        // Judul format sekarang, atau "Langkah berikutnya" dari format lama.
        if (! $last || $last->updated_at->gt(now()->subDay())
            || ! preg_match('/^##\s*(?:Rencana periode berikutnya|Langkah berikutnya)\s*$(.*?)(?=^##\s|\z)/msi', $last->result_md, $match)) {
            return null;
        }

        $since = CarbonImmutable::parse($last->updated_at)->startOfDay();
        $stats = $calc->summary($since, $to);

        return [
            'ditulis' => $since->toDateString(),
            'isi' => trim($match[1]),
            'hasil_sejak_itu' => $stats['total_trades'] === 0 ? null : [
                ...array_intersect_key($stats, array_flip([
                    'total_trades', 'win_rate_pct', 'net_pnl', 'profit_factor', 'expectancy', 'violations',
                ])),
                'perilaku' => $calc->behavior($since, $to),
            ],
        ];
    }

    /** @return array{0: CarbonImmutable, 1: CarbonImmutable, 2: string} */
    private function period(Request $request): array
    {
        return Period::resolve($request->currentAccount(), $request->string('period')->toString());
    }

    /**
     * Kunci cache: isi statistik, bukan rentang tanggal. Data tidak berubah →
     * hasil analisa yang sama dipakai ulang.
     */
    private function hash(array $stats): string
    {
        return sha1(json_encode($stats));
    }
}
