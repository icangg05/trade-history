<?php

namespace App\Http\Controllers;

use App\Models\AiAnalysis;
use App\Services\AccountStats;
use App\Services\Gemini;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use RuntimeException;

class AnalysisController extends Controller
{
    private const PERIODS = ['30d' => 30, '90d' => 90, '1y' => 365];

    public function index(Request $request, Gemini $gemini): Response
    {
        $account = $request->currentAccount();
        [$from, $to, $period] = $this->period($request);

        $stats = (new AccountStats($account))->summary($from, $to);

        return Inertia::render('Analysis', [
            'period' => $period,
            'summary' => $stats,
            'aiEnabled' => $gemini->configured(),
            'model' => $gemini->model(),
            'analysis' => AiAnalysis::where('account_id', $account->id)
                ->where('stats_hash', $this->hash($stats))
                ->latest()
                ->first()
                ?->only('result_md', 'model', 'created_at'),
            'history' => AiAnalysis::where('account_id', $account->id)
                ->latest()
                ->limit(10)
                ->get(['id', 'period_start', 'period_end', 'model', 'created_at']),
        ]);
    }

    public function generate(Request $request, Gemini $gemini): RedirectResponse
    {
        $account = $request->currentAccount();
        [$from, $to] = $this->period($request);

        $stats = (new AccountStats($account))->summary($from, $to);

        if ($stats['total_trades'] === 0) {
            return back()->with('error', 'Belum ada trade tertutup di periode ini.');
        }

        $hash = $this->hash($stats);

        // Statistik identik → hasil lama dipakai ulang, tidak memanggil Gemini lagi.
        if (! $request->boolean('force') && AiAnalysis::where('account_id', $account->id)->where('stats_hash', $hash)->exists()) {
            return back();
        }

        try {
            $markdown = $gemini->analyze($stats, $account->rule?->notes);
        } catch (RuntimeException $e) {
            return back()->with('error', $e->getMessage());
        }

        AiAnalysis::updateOrCreate(
            ['account_id' => $account->id, 'stats_hash' => $hash],
            [
                'period_start' => $from->toDateString(),
                'period_end' => $to->toDateString(),
                'result_md' => $markdown,
                'model' => $gemini->model(),
            ],
        );

        return back()->with('success', 'Analisa selesai.');
    }

    /** Layar chat penuh, terpisah dari halaman analisa supaya muat sampai ujung. */
    public function chatPage(Request $request, Gemini $gemini): Response
    {
        [, , $period] = $this->period($request);

        return Inertia::render('Analysis/Chat', [
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
        [$from, $to] = $this->period($request);

        $stats = (new AccountStats($account))->summary($from, $to);

        if ($stats['total_trades'] === 0) {
            return response()->json(['error' => 'Belum ada trade di periode ini untuk dibahas.'], 422);
        }

        // Pertanyaan baru selalu ditempel di ujung: urutan giliran ditentukan di
        // sini, bukan dipercayakan pada apa yang dikirim browser.
        $messages = [...($data['history'] ?? []), ['role' => 'user', 'text' => $data['message']]];

        try {
            $reply = $gemini->chat($stats, $account->rule?->notes, $messages);
        } catch (RuntimeException $e) {
            return response()->json(['error' => $e->getMessage()], 502);
        }

        return response()->json(['reply' => $reply]);
    }

    /** @return array{0: CarbonImmutable, 1: CarbonImmutable, 2: string} */
    private function period(Request $request): array
    {
        $period = $request->string('period')->toString() ?: '30d';
        $to = CarbonImmutable::now()->endOfDay();

        if ($period === 'all') {
            return [CarbonImmutable::parse($request->currentAccount()->started_at), $to, 'all'];
        }

        $days = self::PERIODS[$period] ?? 30;

        return [$to->subDays($days)->startOfDay(), $to, array_key_exists($period, self::PERIODS) ? $period : '30d'];
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
