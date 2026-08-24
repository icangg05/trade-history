<?php

namespace App\Http\Controllers;

use App\Services\Gemini;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

/**
 * Screenshot → Gemini → field terisi di form.
 *
 * Gambar TIDAK disimpan: dibaca dari memori, dipakai sekali, lalu dilepas.
 * Yang tersimpan hanya hasil bacaannya di kolom `ai_raw` milik trade.
 *
 * Sengaja sinkron (bukan queue): satu pengguna, sekali proses ~3-8 detik.
 * ponytail: pindahkan ke queue + polling kalau nanti terasa mengganggu.
 */
class TradeImportController extends Controller
{
    /** Tanpa ketiganya, sebuah baris trade tidak ada artinya. */
    private const REQUIRED = [
        'symbol' => 'simbol',
        'direction' => 'arah posisi',
        'entry_price' => 'harga entry',
    ];

    public function __invoke(Request $request, Gemini $gemini): JsonResponse
    {
        $request->validate([
            'screenshot' => ['required', 'image', 'max:8192'],
        ]);

        if (! $gemini->configured()) {
            return response()->json([
                'error' => 'Kunci Gemini belum ditambahkan admin — silakan isi form secara manual.',
            ], 503);
        }

        $file = $request->file('screenshot');

        try {
            $extracted = $gemini->extractTrade($file->get(), $file->getMimeType());
        } catch (RuntimeException $e) {
            Log::warning('Gemini extract gagal', ['message' => $e->getMessage()]);

            return response()->json(['error' => $e->getMessage().' Isi form secara manual.'], 502);
        }

        if (! ($extracted['is_trade_screenshot'] ?? false)) {
            return response()->json([
                'error' => 'Gambar ini bukan screenshot posisi trading. Unggah tangkapan layar '
                    .'MetaTrader, TradingView, atau riwayat order dari broker.',
            ], 422);
        }

        $data = $this->toFormFields($extracted);
        $missing = array_keys(array_filter(
            self::REQUIRED,
            fn (string $key) => blank($data[$key] ?? null),
            ARRAY_FILTER_USE_KEY,
        ));

        if ($missing) {
            $labels = array_map(fn (string $key) => self::REQUIRED[$key], $missing);

            return response()->json([
                'error' => 'Data di gambar tidak lengkap — '.implode(', ', $labels)
                    .' tidak terbaca. Unggah screenshot yang lebih jelas, atau isi form manual.',
                'missing' => $missing,
            ], 422);
        }

        return response()->json([
            'data' => $data,
            'low_confidence_fields' => $extracted['low_confidence_fields'] ?? [],
            'raw' => $extracted,
        ]);
    }

    /**
     * Bentuk ulang jadi nama field form. Nilai yang tidak masuk akal dibuang
     * di sini — sisanya tetap lewat validasi TradeRequest saat disimpan.
     */
    private function toFormFields(array $e): array
    {
        $positive = fn (string $key) => is_numeric($e[$key] ?? null) && (float) $e[$key] > 0
            ? (float) $e[$key]
            : null;

        $openedAt = $this->datetime($e['opened_at'] ?? null);
        $closedAt = $this->datetime($e['closed_at'] ?? null);
        $pnl = is_numeric($e['pnl'] ?? null) ? (float) $e['pnl'] : null;

        // Posisi yang sudah punya hasil pasti punya waktu tutup. Kalau tidak
        // terbaca di gambar, waktu buka dipakai supaya field tidak kosong.
        if ($pnl !== null && $closedAt === null) {
            $closedAt = $openedAt;
        }

        return [
            'symbol' => filled($e['symbol'] ?? null) ? strtoupper($e['symbol']) : null,
            'direction' => in_array($e['direction'] ?? null, ['buy', 'sell'], true) ? $e['direction'] : null,
            'lot' => $positive('lot'),
            'entry_price' => $positive('entry_price'),
            'sl_price' => $positive('sl_price'),
            'tp_price' => $positive('tp_price'),
            'exit_price' => $positive('exit_price'),
            'pnl' => $pnl,
            'opened_at' => $openedAt,
            'closed_at' => $closedAt,
            'setup' => filled($e['setup'] ?? null) ? mb_substr($e['setup'], 0, 255) : null,
            'notes' => $e['notes'] ?? null,
        ];
    }

    private function datetime(?string $value): ?string
    {
        if (blank($value)) {
            return null;
        }

        try {
            return CarbonImmutable::parse($value)->format('Y-m-d\TH:i');
        } catch (Throwable) {
            return null;
        }
    }
}
