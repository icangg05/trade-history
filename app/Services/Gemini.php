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
 *   2. analyze()      — terima statistik & pola perilaku yang SUDAH dihitung, kembalikan markdown.
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
          sama dengan `opened_at`.
        - `exit_price` HANYA diisi bila harga penutupan benar-benar tertulis di gambar.
          JANGAN menyalin nilai S/L atau T/P ke sana, dan jangan menyimpulkan harga
          penutupan dari untung/rugi. Tidak tertulis → null.
        - `lot` adalah ukuran posisi/volume (contoh: 0.05).
        - `pnl` adalah profit/loss akhir dalam mata uang akun.
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
     * Penjelasan isi DATA — dipakai analyze() dan chat() supaya kedua model
     * membaca bahan yang sama dengan cara yang sama.
     */
    private const DATA_GUIDE = <<<'TXT'
    DATA (JSON) sudah dihitung dari database — angkanya benar. Pakai apa adanya,
    jangan hitung ulang, jangan mengarang angka yang tidak ada. Membandingkan dua
    angka yang ada (selisih, "dua kali lipat") boleh.
    - `statistik`: ringkasan periode ini, termasuk breakdown `by_symbol`,
      `by_direction`, `by_weekday`, `by_hour` (jam buka, WIB), `by_setup`, dan
      `violations` (tanggal → aturan yang dilanggar). `max_drawdown` diukur dari
      seluruh umur akun, bukan periode ini.
    - `perilaku`: kebiasaan di balik angka — `by_trade_of_day` (posisi ke-berapa
      dalam sehari), `after_loss` (dibuka ≤60 menit setelah posisi rugi, dibanding
      lainnya), `hold_minutes` (rata-rata lama posisi menang vs kalah),
      `avg_lot` (setelah win vs setelah loss), `by_stop` (letak SL saat ditutup),
      `by_rr_planned` (kelompok RR rencana), `days` (hari hijau vs merah, hari
      terbaik & terburuk).
    - `periode_sebelumnya`: angka inti periode sepanjang ini tepat sebelumnya;
      null kalau tidak ada pembanding.
    - `aturan_terpasang`: aturan yang sedang aktif di aplikasi (null kalau belum
      ada); `notes` adalah catatan pribadi trader.
    - `rencana_sebelumnya`: rencana dari analisa terakhir, tanggal ditulis, dan
      `hasil_sejak_itu` (statistik + perilaku trade setelah tanggal itu); null
      kalau belum ada.

    Cara menilai:
    - Kelompok dengan kurang dari 5 trade belum bisa disebut pola; sebut sebagai
      dugaan.
    - Urutkan temuan dari dampak P/L terbesar, bukan dari yang paling menarik.
    - Kebiasaan biasanya bocor lebih besar daripada pilihan setup: terlalu
      banyak posisi per hari, masuk lagi tak lama setelah loss, menahan posisi
      rugi lebih lama dari posisi untung, lot membesar setelah loss, trade tanpa
      SL. Sebut hanya yang didukung data.
    TXT;

    /**
     * Evaluasi periode: di mana uang bocor, apa yang terbukti menghasilkan, dan
     * rencana terukur yang dinilai lagi di analisa berikutnya.
     */
    public function analyze(array $context): string
    {
        $prompt = <<<'TXT'
        Kamu pelatih performa trading. Tugasmu bukan merangkum statistik, tapi
        menemukan apa yang paling membuat trader ini kehilangan uang, apa yang
        terbukti menghasilkan, dan memberi rencana terukur untuk periode berikutnya
        yang akan dinilai lagi di analisa selanjutnya. Dibaca di ponsel: padat dan
        langsung, setiap kalimat membawa angka, temuan, atau instruksi.
        TXT;

        $format = <<<'TXT'
        Tulis Bahasa Indonesia dengan markdown, tepat enam bagian ini, urut:

        ## Ringkasan
        Tiga sampai empat kalimat: hasil periode ini (jumlah trade, P/L bersih,
        winrate, profit factor); dibanding `periode_sebelumnya` membaik atau
        memburuk, dan angka mana yang paling bergerak (lewati kalau null); lalu
        satu kalimat berisi kebocoran terbesar.

        ## Kebocoran terbesar
        Satu pola yang paling banyak menggerus uang, dengan buktinya (jumlah
        trade, P/L, winrate dibanding sisanya) dan kira-kira P/L seandainya pola
        itu dilewati. Kalau ada kebocoran kedua yang dampaknya hampir sama,
        tambahkan singkat. Pakai `>` untuk kalimat intinya.

        ## Yang terbukti menghasilkan
        1-3 pola dengan sampel cukup yang layak diperbanyak, dengan angkanya, dan
        apa yang membedakannya dari trade lain.

        ## Cek perilaku
        Tabel `| Perilaku | Angka | Status |` untuk: posisi ke-3+ per hari,
        masuk ≤60 menit setelah loss, lama posisi rugi vs untung, lot setelah loss
        vs setelah win, trade tanpa SL. Status satu kata: **Aman**, **Waspada**,
        atau **Bocor**. Lewati baris yang datanya kosong.

        ## Evaluasi rencana sebelumnya
        Kalau `rencana_sebelumnya` ada: tiap butirnya dijalankan atau tidak
        (nilai dari `hasil_sejak_itu`), dan dampaknya ke hasil. Kalau null, satu
        kalimat saja: belum ada rencana sebelumnya untuk dinilai.

        ## Rencana periode berikutnya
        **Fokus utama:** satu kebiasaan yang diubah, satu kalimat.

        Lalu paling banyak tiga aturan bernomor. Tiap aturan: angka yang jelas dan
        alasannya dari data. Kalau cocok dengan kolom di halaman Aturan aplikasi,
        tulis nama kolomnya persis — "Maks. trade / hari", "Maks. loss harian",
        "Maks. loss / trade", "RR minimum", "Maks. drawdown", atau "Sesi"
        (Sydney, Tokyo, London, New York) — dan bandingkan dengan
        `aturan_terpasang` kalau sudah ada nilainya.

        Tutup dengan **Target:** satu atau dua angka yang harus tercapai di
        analisa berikutnya (mis. profit factor ≥ 1,5, atau P/L posisi ke-3+ tidak
        lagi negatif) supaya kemajuannya bisa diukur.

        Larangan: sinyal, prediksi arah pasar, rekomendasi entry; nasihat tanpa
        angka ("jaga emosi", "lebih disiplin"); paragraf pembuka atau penutup di
        luar enam bagian; mengulang angka yang sama di banyak bagian. Kalau
        `statistik.total_trades` di bawah 10, awali Ringkasan dengan satu kalimat
        bahwa sampelnya masih kecil sehingga semua temuan adalah dugaan.
        TXT;

        $data = 'DATA:'."\n".json_encode($context, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

        $response = $this->call([
            'contents' => [[
                'parts' => [['text' => $prompt."\n\n".self::DATA_GUIDE."\n\n".$format."\n\n".$data]],
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
    public function chat(array $context, array $messages): string
    {
        $system = <<<'TXT'
        Kamu pelatih performa trading yang sedang berbicara langsung dengan pemilik
        jurnal ini. Jawab pertanyaannya tentang cara dia trading, berdasarkan DATA
        di bawah. Kalau sebuah pertanyaan tidak bisa dijawab dari data yang ada,
        katakan terus terang data mana yang kurang, jangan menebak.

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

        $data = 'DATA:'."\n".json_encode($context, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

        $response = $this->call([
            'systemInstruction' => ['parts' => [['text' => $system."\n\n".self::DATA_GUIDE."\n\n".$data]]],
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
