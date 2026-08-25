<?php

namespace App\Services;

use App\Models\GeminiKey;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Pembungkus tipis REST API Gemini. Dua kegunaan:
 *   1. extractTrade() — baca screenshot chart, kembalikan field trade (JSON terstruktur).
 *   2. analyze()      — terima statistik yang SUDAH dihitung + aturan, kembalikan markdown.
 *
 * Statistik tidak pernah dihitung oleh model: angka datang dari AccountStats,
 * model hanya menafsirkan.
 */
class Gemini
{
    private const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

    public function model(): string
    {
        return config('services.gemini.model');
    }

    public function configured(): bool
    {
        return GeminiKey::query()->exists();
    }

    /** Uji satu kunci dengan permintaan sekali pakai yang murah. */
    public function ping(GeminiKey $key): string
    {
        // Tema diacak di sini, bukan diserahkan ke suhu model: tanpa ini model
        // hampir selalu mengembalikan kalimat yang itu-itu juga.
        $tema = collect([
            'disiplin mengikuti rencana', 'kesabaran menunggu setup', 'manajemen risiko',
            'konsistensi jangka panjang', 'belajar dari kerugian', 'mental saat drawdown',
            'masa depan finansial', 'kebebasan waktu', 'menikmati proses, bukan hasil sesaat',
            'berhenti membalas dendam ke pasar', 'syukur atas profit kecil', 'jurnal dan evaluasi',
            'modal yang dijaga hari ini', 'keyakinan pada sistem sendiri', 'istirahat setelah rugi beruntun',
        ])->random();

        $response = $this->call([
            'contents' => [['parts' => [['text' => sprintf(
                'Tulis SATU kalimat motivasi untuk seorang trader bertema "%s". Maksimal 15 kata, '
                .'bahasa Indonesia, gaya segar dan tidak klise. Balas hanya kalimat itu, tanpa tanda kutip.',
                $tema
            )]]]],
            'generationConfig' => ['temperature' => 1.5, 'maxOutputTokens' => 512],
        ], $key);

        return trim($this->text($response));
    }

    // ------------------------------------------------------------------ vision

    /**
     * Ekstrak data trade dari screenshot chart / order.
     *
     * @return array{
     *     is_trade_screenshot: bool, symbol: ?string, direction: ?string, lot: ?float,
     *     entry_price: ?float, sl_price: ?float, tp_price: ?float,
     *     exit_price: ?float, pnl: ?float, opened_at: ?string, closed_at: ?string,
     *     setup: ?string, notes: ?string, low_confidence_fields: list<string>
     * }
     */
    public function extractTrade(string $imageBytes, string $mimeType): array
    {
        $prompt = <<<'TXT'
        Kamu membaca screenshot platform trading (MetaTrader / TradingView / posisi broker).
        Ambil data satu posisi trading dari gambar.

        Pertama, tentukan `is_trade_screenshot`: apakah gambar ini benar-benar layar
        platform trading yang memuat data posisi (simbol, harga, order)? Foto orang,
        tangkapan layar chat, meme, dokumen, atau gambar acak → false, dan seluruh field
        lain diisi null.

        Aturan keras:
        - Kembalikan HANYA angka yang benar-benar terbaca di gambar.
        - Jika sebuah nilai tidak terlihat jelas, isi null. JANGAN menebak, jangan menghitung
          ulang, jangan mengarang harga yang "masuk akal".
        - `direction` hanya "buy" atau "sell". Long/Beli = buy, Short/Jual = sell.
        - Harga sebagai angka desimal polos tanpa pemisah ribuan (contoh: 2412.35).
        - `opened_at` dan `closed_at` format "YYYY-MM-DD HH:mm" (24 jam).
          `closed_at` adalah waktu posisi ditutup — di MetaTrader biasanya kolom "Time"
          kedua pada baris riwayat, atau "Close Time". Kalau posisi sudah tertutup
          (ada profit/loss akhir) tetapi waktu tutup tidak terlihat, isi `closed_at`
          sama dengan `opened_at`. Null hanya bila posisi memang masih terbuka.
        - `exit_price` HANYA diisi bila harga penutupan benar-benar tertulis di gambar.
          JANGAN menyalin nilai S/L atau T/P ke sana, dan jangan menyimpulkan harga
          penutupan dari untung/rugi. Tidak tertulis → null.
        - `lot` adalah ukuran posisi/volume (contoh: 0.05).
        - `pnl` adalah profit/loss dalam mata uang akun; null jika posisi masih terbuka.
        - `setup` diisi hanya jika nama strategi/pola tertulis di gambar.
        - `notes` maksimal satu kalimat berisi konteks lain yang terbaca (timeframe, sesi, dsb).
        - Cantumkan setiap field yang kamu ragukan di `low_confidence_fields`.
        TXT;

        $schema = [
            'type' => 'object',
            'properties' => [
                'is_trade_screenshot' => ['type' => 'boolean'],
                'symbol' => ['type' => 'string', 'nullable' => true],
                'direction' => ['type' => 'string', 'enum' => ['buy', 'sell'], 'nullable' => true],
                'lot' => ['type' => 'number', 'nullable' => true],
                'entry_price' => ['type' => 'number', 'nullable' => true],
                'sl_price' => ['type' => 'number', 'nullable' => true],
                'tp_price' => ['type' => 'number', 'nullable' => true],
                'exit_price' => ['type' => 'number', 'nullable' => true],
                'pnl' => ['type' => 'number', 'nullable' => true],
                'opened_at' => ['type' => 'string', 'nullable' => true],
                'closed_at' => ['type' => 'string', 'nullable' => true],
                'setup' => ['type' => 'string', 'nullable' => true],
                'notes' => ['type' => 'string', 'nullable' => true],
                'low_confidence_fields' => ['type' => 'array', 'items' => ['type' => 'string']],
            ],
            'required' => ['is_trade_screenshot', 'low_confidence_fields'],
        ];

        $response = $this->call([
            'contents' => [[
                'parts' => [
                    ['text' => $prompt],
                    ['inline_data' => ['mime_type' => $mimeType, 'data' => base64_encode($imageBytes)]],
                ],
            ]],
            'generationConfig' => [
                'temperature' => 0,
                'responseMimeType' => 'application/json',
                'responseSchema' => $schema,
            ],
        ]);

        $data = json_decode($this->text($response), true);

        if (! is_array($data)) {
            throw new RuntimeException('Gemini mengembalikan JSON yang tidak bisa dibaca.');
        }

        return $data + ['is_trade_screenshot' => false, 'low_confidence_fields' => []];
    }

    // ----------------------------------------------------------------- analisa

    /**
     * Analisa periode berdasarkan statistik yang sudah jadi.
     */
    public function analyze(array $stats, ?string $rules = null): string
    {
        $prompt = <<<'TXT'
        Kamu mentor trading yang membaca jurnal seorang trader dan menulis evaluasi
        periode ini untuknya.

        Statistik di bawah SUDAH DIHITUNG dari database — angka itu benar, pakai apa
        adanya, jangan hitung ulang dan jangan mengarang angka yang tidak ada di sana.
        Kamu boleh membandingkan angka satu sama lain (mis. rata-rata rugi terhadap
        rugi terbesar), tapi setiap angka yang kamu sebut harus berasal dari data.

        Tulis dalam Bahasa Indonesia dengan markdown. Panjangnya bebas — sepanjang yang
        dibutuhkan, sependek yang cukup. Yang dinilai bukan jumlah kata melainkan
        kepadatannya: setiap kalimat harus membawa temuan, angka, atau instruksi.
        Buang kalimat yang hanya mengantar, mengulang, atau menyemangati.

        Pakai format seperlunya supaya cepat dibaca, jangan menulis dinding paragraf:
        - **tebal** untuk angka kunci dan nama pola
        - *miring* untuk istilah atau catatan sisi
        - daftar berpoin untuk temuan sejajar, daftar bernomor untuk langkah berurutan
        - tabel markdown kalau membandingkan tiga hal atau lebih (mis. per simbol atau per jam)
        - `>` untuk satu peringatan yang paling penting, kalau memang ada

        Susun tujuh bagian berikut:

        ## Ringkasan
        Isi terpadat dari seluruh tulisan. Sebut jumlah trade, P/L bersih, winrate, dan
        profit factor, lalu satu kalimat kesimpulan: periode ini menghasilkan atau
        menggerus modal, dan angka mana yang paling menentukan hasil itu. Kalau ada satu
        hal yang paling mendesak untuk diperbaiki, sebut di sini.

        ## Kualitas eksekusi
        Winrate bersama payoff ratio dan ekspektasi per trade: keuntungan datang dari
        sering benar, atau dari sedikit menang besar? Bandingkan `avg_rr_planned` dengan
        `avg_rr_realized` — selisih besar berarti posisi ditutup lebih awal atau
        melenceng dari rencana, katakan mana yang terjadi. Bandingkan `avg_loss` dengan
        `largest_loss`; kalau rugi terbesar jauh melampaui rata-rata, tunjuk itu sebagai
        satu kejadian yang merusak statistik, bukan sebagai pola.

        ## Model & strategi
        Bagian terpenting. Dari `by_setup`, `by_direction`, `by_symbol`, `by_hour`,
        `by_weekday`, RR, dan catatan aturan trader, simpulkan seperti apa sebenarnya
        cara dia trading — apakah lebih condong scalping atau menahan posisi, searah
        atau melawan tren, satu instrumen atau menyebar, satu jam favorit atau acak,
        RR-nya konsisten atau berubah-ubah. Tulis pembacaan itu terlebih dulu, lalu
        pecah jadi dua daftar:

        **Yang sudah bagus** — kebiasaan yang datanya membuktikan berhasil, dengan
        angkanya, dan alasan kenapa itu layak dipertahankan.

        **Yang masih kurang** — celah yang datanya menunjukkan merugikan atau tidak
        konsisten, dengan angkanya, dan akibat yang terlihat di statistik. Termasuk
        kalau datanya sendiri belum cukup untuk menilai (mis. setup tidak pernah diisi,
        SL/TP tidak dicatat), karena itu juga kekurangan strateginya.

        ## Pola yang menghasilkan
        2-3 kombinasi paling menguntungkan dari breakdown, lengkap dengan jumlah trade,
        P/L, dan winrate. Kalau satu kelompok hanya berisi sedikit trade, katakan terus
        terang bahwa sampelnya belum cukup untuk disimpulkan.

        ## Pola yang merugikan
        Cara yang sama untuk sisi rugi. Tunjuk yang paling layak dihentikan lebih dulu
        dan sebutkan berapa kerugian yang bisa dihindari kalau kelompok itu dilewati.

        ## Risiko & disiplin
        `max_drawdown` (nominal dan persen), `longest_loss_streak`, dan `open_trades`.
        Kalau `violations` berisi tanggal pelanggaran, sebut berapa hari yang melanggar
        dan aturan mana yang paling sering dilanggar. Kalau trader menulis aturannya
        sendiri di bawah, nilai kepatuhannya terhadap aturan itu secara spesifik. Kalau
        `violations` kosong, katakan disiplinnya terjaga.

        ## Langkah berikutnya
        Daftar bernomor, 4-6 butir, diurutkan dari yang paling berdampak. Masing-masing
        satu kalimat, bisa dikerjakan minggu depan, dan menyebut angka target yang
        diturunkan dari data di atas — batas trade per hari, jam yang dihindari, RR
        minimum, ukuran lot, dan sejenisnya. Nasihat umum tanpa angka ("jaga disiplin",
        "kelola emosi") dilarang.

        Larangan: jangan memberi sinyal, prediksi arah pasar, atau rekomendasi entry.
        Jangan menulis paragraf pembuka atau penutup di luar tujuh bagian itu. Jangan
        mengulang angka yang sama persis di dua bagian kecuali memang sedang
        dibandingkan. Kalau `total_trades` di bawah 10, tetap tulis ketujuh bagian tapi
        awali Ringkasan dengan satu kalimat bahwa sampelnya masih terlalu kecil untuk
        disimpulkan sebagai pola.
        TXT;

        $payload = "STATISTIK:\n".json_encode($stats, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

        if (filled($rules)) {
            $payload .= "\n\nATURAN TRADING YANG DITULIS TRADER:\n".$rules;
        }

        $response = $this->call([
            'contents' => [[
                'parts' => [['text' => $prompt."\n\n".$payload]],
            ]],
            // Batas atas yang longgar: panjangnya ditentukan isi, bukan dipangkas
            // di tengah kalimat. Pemakaian sebenarnya tetap dihitung ke kuota TPM.
            'generationConfig' => ['temperature' => 0.4, 'maxOutputTokens' => 8000],
        ]);

        return trim($this->text($response));
    }

    /**
     * Tanya jawab bebas seputar akun ini.
     *
     * Statistik yang sama dengan analyze() dikirim sebagai instruksi sistem —
     * model menjawab pertanyaan, tidak menghitung ulang angkanya.
     *
     * @param  list<array{role: string, text: string}>  $messages  urut lama → baru, yang terakhir dari trader
     */
    public function chat(array $stats, ?string $rules, array $messages): string
    {
        $system = <<<'TXT'
        Kamu mentor trading yang sedang berbicara langsung dengan pemilik jurnal ini.
        Jawab pertanyaannya tentang cara dia trading, berdasarkan STATISTIK AKUN di bawah.

        Angka di STATISTIK AKUN sudah dihitung dari database — pakai apa adanya,
        jangan hitung ulang dan jangan mengarang angka yang tidak ada di sana. Kalau
        sebuah pertanyaan tidak bisa dijawab dari data yang ada, katakan terus terang
        data mana yang kurang, jangan menebak.

        Gaya jawaban:
        - Bahasa Indonesia, santai tapi padat. Ini percakapan, bukan laporan.
        - Pendek secukupnya — biasanya 2-5 kalimat atau satu daftar singkat.
          Panjangkan hanya kalau pertanyaannya memang menuntut itu.
        - Markdown seperlunya: **tebal** untuk angka kunci, daftar berpoin untuk
          hal sejajar. Jangan pakai judul `##` dan jangan membuat laporan tujuh bagian.
        - Setiap klaim tentang cara dia trading harus menyebut angka pendukungnya.
        - Jangan mengulang seluruh statistik kalau yang ditanya cuma satu hal.

        Larangan: jangan memberi sinyal, prediksi arah pasar, atau rekomendasi entry.
        Kalau ditanya hal itu, tolak singkat lalu belokkan ke apa yang bisa dibaca
        dari jurnalnya sendiri.
        TXT;

        $context = "STATISTIK AKUN:\n".json_encode($stats, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

        if (filled($rules)) {
            $context .= "\n\nATURAN TRADING YANG DITULIS TRADER:\n".$rules;
        }

        $response = $this->call([
            'systemInstruction' => ['parts' => [['text' => $system."\n\n".$context]]],
            'contents' => array_map(fn (array $message): array => [
                'role' => $message['role'] === 'assistant' ? 'model' : 'user',
                'parts' => [['text' => $message['text']]],
            ], $messages),
            'generationConfig' => ['temperature' => 0.6, 'maxOutputTokens' => 2000],
        ]);

        return trim($this->text($response));
    }

    // ---------------------------------------------------------------- internal

    /** Kunci boleh ditentukan (uji satu kunci); kalau tidak, giliran yang menentukan. */
    private function call(array $body, ?GeminiKey $key = null): array
    {
        $key = $key?->claim() ?? GeminiKey::next();

        try {
            $response = Http::withHeaders(['x-goog-api-key' => $key->api_key])
                ->timeout(120)
                // 429 dari Google = kuota kunci itu memang habis. Mengulang tidak menolong.
                ->retry(2, 1000, fn ($e) => ! ($e instanceof RequestException && $e->response->status() === 429), throw: false)
                ->post(self::ENDPOINT.'/'.$this->model().':generateContent', $body);
        } catch (ConnectionException $e) {
            throw new RuntimeException('Tidak bisa menghubungi Gemini: '.$e->getMessage(), previous: $e);
        }

        $json = $response->json() ?? [];

        if ($response->status() === 429) {
            throw new RuntimeException('Kuota kunci "'.$key->name.'" di sisi Google habis. Coba lagi nanti atau tambah kunci lain.');
        }

        if ($response->failed()) {
            $message = data_get($json, 'error.message') ?? $response->body();

            throw new RuntimeException('Gemini menolak permintaan ('.$response->status().'): '.$message);
        }

        return $json;
    }

    private function text(array $response): string
    {
        $parts = data_get($response, 'candidates.0.content.parts', []);
        $text = collect($parts)->pluck('text')->filter()->implode('');

        if (blank($text)) {
            $reason = data_get($response, 'candidates.0.finishReason', 'tidak diketahui');

            throw new RuntimeException('Gemini tidak mengembalikan teks (finishReason: '.$reason.').');
        }

        return $text;
    }
}
