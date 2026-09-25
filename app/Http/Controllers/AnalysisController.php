<?php

namespace App\Http\Controllers;

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

        $stats = (new AccountStats($account))->summary($from, $to);
        $hash = $this->hash($stats);

        // Cocok persis dulu; kalau statistik sudah berubah, analisa terakhir
        // tetap ditampilkan (ditandai usang) supaya bacaannya tidak hilang
        // begitu satu trade baru masuk.
        $saved = AiAnalysis::where('account_id', $account->id)->latest();
        $analysis = (clone $saved)->where('stats_hash', $hash)->first() ?? $saved->first();

        return $this->page('Analysis', [
            'period' => $period,
            'summary' => $stats,
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
        [$from, $to] = $this->period($request);

        $stats = (new AccountStats($account))->summary($from, $to);

        if ($stats['total_trades'] === 0) {
            return $this->failed('Belum ada trade tertutup di periode ini.');
        }

        // Tombol ini selalu memanggil Gemini: diam-diam memakai ulang hasil lama
        // terbaca seperti tombol rusak. Pemborosannya ditahan di tempat lain —
        // jeda 10 detik per kunci (GeminiKey::COOLDOWN) dan throttle rute.
        try {
            $markdown = $gemini->analyze($stats, $account->rule?->notes);
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
