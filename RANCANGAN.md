# Trade History — Rancangan

Aplikasi pencatat & analisa jurnal trading pribadi. Multi-akun, tiap akun punya
history + aturan sendiri. Single user (kamu), jadi banyak hal boleh sederhana.

---

## 1. Stack & keputusan

| Bagian | Pilihan | Catatan |
|---|---|---|
| Backend | Laravel 13 | monolith, tanpa API terpisah |
| Frontend | Inertia v3 + Vue 3 (`<script setup>`, TS) | tanpa router/state manager sendiri |
| Styling | Tailwind CSS v4 | CSS-first, **tidak ada** `tailwind.config.js` |
| Komponen | shadcn-vue (reka-ui) | `components.json`, alias `@/components/ui` |
| Ikon | `@lucide/vue` | default shadcn-vue |
| Font | IBM Plex Sans (+ IBM Plex Mono untuk angka) | self-host via `bunny()` di laravel-vite-plugin |
| DB | MySQL 8.4 | |
| Runtime | FrankenPHP + Laravel Octane (worker mode) | 1 container serve HTTP+PHP |
| Build FE | Vite 8 (rolldown) | TypeScript dipatok `^5.9`, lihat §10 |
| AI | Gemini API (`gemini-3.5-flash`) | vision untuk OCR chart, text untuk analisa |
| Chart | SVG buatan sendiri | shadcn-vue tidak lagi punya komponen chart di registry |
| Tema | **dark only** | tidak ada toggle, tidak ada class `.dark` |
| PWA | manifest + service worker tulis tangan | bisa dipasang di home screen; aset build di-cache, HTML selalu dari jaringan |

Yang **tidak** dipakai: queue worker (kecuali nanti terasa lambat), Redis,
websocket, state manager, komponen calendar shadcn (dipakai grid manual).

---

## 2. Design system

Diambil dari `nfp`, **hanya nilai dark mode**, di-flatten ke `:root`.
Tidak ada `.dark`, tidak ada `prefers-color-scheme` — satu tema saja.

`resources/css/app.css`:

```css
@import "tailwindcss";
@import "tw-animate-css";

/* Tema selalu dark: varian `dark:` bawaan komponen shadcn dibuat selalu aktif. */
@custom-variant dark (&);

/* --- Token warna: nfp dark, di-flatten --- */
:root {
  --background: 222 30% 6%;
  --foreground: 210 24% 94%;

  --card: 220 26% 11%;
  --card-foreground: 210 24% 94%;

  --popover: 221 28% 9%;
  --popover-foreground: 210 24% 94%;

  --primary: 43 96% 56%;            /* gold */
  --primary-foreground: 40 65% 8%;

  --secondary: 220 20% 16%;
  --secondary-foreground: 210 24% 94%;

  --muted: 220 18% 15%;
  --muted-foreground: 216 16% 62%;

  --accent: 220 22% 18%;
  --accent-foreground: 43 96% 62%;

  --gold: 43 96% 56%;
  --gold-foreground: 40 65% 8%;
  --cyan: 187 92% 56%;

  --destructive: 0 74% 56%;         /* = loss */
  --destructive-foreground: 210 40% 98%;
  --success: 152 66% 46%;           /* = profit */
  --success-foreground: 220 30% 8%;

  --border: 216 24% 22%;
  --input: 216 24% 24%;
  --ring: 43 96% 56%;

  --glass-bg: 220 26% 13%;
  --glass-alpha: 0.55;
  --glass-border: 0 0% 100%;
  --glass-border-alpha: 0.06;

  --radius: 0.75rem;
}

@theme inline {
  --color-background: hsl(var(--background));
  --color-foreground: hsl(var(--foreground));
  --color-card: hsl(var(--card));
  --color-card-foreground: hsl(var(--card-foreground));
  --color-popover: hsl(var(--popover));
  --color-popover-foreground: hsl(var(--popover-foreground));
  --color-primary: hsl(var(--primary));
  --color-primary-foreground: hsl(var(--primary-foreground));
  --color-secondary: hsl(var(--secondary));
  --color-secondary-foreground: hsl(var(--secondary-foreground));
  --color-muted: hsl(var(--muted));
  --color-muted-foreground: hsl(var(--muted-foreground));
  --color-accent: hsl(var(--accent));
  --color-accent-foreground: hsl(var(--accent-foreground));
  --color-destructive: hsl(var(--destructive));
  --color-destructive-foreground: hsl(var(--destructive-foreground));
  --color-success: hsl(var(--success));
  --color-success-foreground: hsl(var(--success-foreground));
  --color-gold: hsl(var(--gold));
  --color-cyan: hsl(var(--cyan));
  --color-border: hsl(var(--border));
  --color-input: hsl(var(--input));
  --color-ring: hsl(var(--ring));

  --font-sans: "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "IBM Plex Mono", ui-monospace, monospace;

  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
}

@layer base {
  * { border-color: hsl(var(--border)); }
  body { @apply bg-background text-foreground antialiased font-sans; }
  h1, h2, h3 { @apply tracking-tight font-semibold; }
  /* semua angka uang/harga pakai .font-mono + tabular-nums */
}
```

Utilities yang di-port apa adanya dari `nfp/assets/css/main.css` (versi dark saja):

- `.glass` / `.glass-card` — permukaan translusen + blur + garis kilau atas.
  Dipakai untuk stat card, panel kalender, dialog.
- `.bg-ornaments` + `.bg-grid` + `.blob-a/.blob-b` + `.ring-ornament` — layer
  `position: fixed; z-index: -10` di layout utama. Ambil hanya blok `.dark`.
- `.hover-lift` — border jadi `gold/.30` saat hover.
- Scrollbar kustom (gold on hover) + `.table-scroll`.
- `.pb-safe` untuk tab bar mobile.

**Aturan warna semantik:**
- Gold = aksi utama, highlight, brand. Bukan untuk profit.
- `success` = profit / hari hijau. `destructive` = loss / hari merah / pelanggaran aturan.
- `cyan` = data sekunder di chart (mis. garis deposit/withdrawal), ornamen.
- Nol / breakeven = `muted-foreground`.

**Tipografi:** IBM Plex Sans untuk teks & heading, IBM Plex Mono untuk semua
angka (harga, lot, P/L, saldo) supaya kolom tabel rata — `tabular-nums`.

---

## 3. Struktur folder

```
app/
  Http/Controllers/  AccountController, TradeController, TransactionController,
                     RuleController, CalendarController, AnalysisController,
                     TradeImportController
  Models/            User, Account, Transaction, Trade, AccountRule, AiAnalysis
  Services/          Gemini.php          # 1 file, 2 method: extractTrade(), analyze()
                     AccountStats.php    # semua agregasi & equity curve
resources/
  css/app.css
  js/
    app.ts
    layouts/AppLayout.vue        # header + account switcher + ornamen + tab bar
    components/ui/…              # shadcn-vue
    components/                  # EquityChart, PnlCalendar, TradeForm, StatCard,
                                 # RuleStatusBanner, AiImportDialog
    pages/                       # Dashboard, Accounts, Trades/*, Calendar, Rules, Analysis
    lib/utils.ts                 # cn()
routes/web.php
database/migrations/
docker/  Caddyfile, php.ini
compose.yml  Dockerfile
```

---

## 4. Skema database

```
users ─┬─< accounts ─┬─< transactions
       │             ├─< trades
       │             ├─── account_rules   (1:1)
       │             └─< ai_analyses
```

### accounts
| kolom | tipe | ket |
|---|---|---|
| id | bigint pk | |
| user_id | fk | |
| name | string | "FTMO 10k", "Real Exness" |
| broker | string null | |
| currency | char(3) default USD | hanya `USD`, `USC` (akun sen), `IDR` |
| initial_balance | decimal(18,2) | saldo awal |
| started_at | date | tanggal saldo awal berlaku |
| is_archived | bool default 0 | |
| timestamps | | |

### transactions
`id, account_id, type enum('deposit','withdrawal'), amount decimal(18,2),
occurred_at date, proof_path string null, note text null, timestamps`
Index: `(account_id, occurred_at)`

`proof_path` = bukti transfer, **wajib** lewat form (nullable di DB hanya supaya
data seeder tetap valid). Disimpan di disk privat, keluar lewat
`/transactions/{id}/proof` setelah kepemilikan dicek.

### trades
| kolom | tipe | ket |
|---|---|---|
| id | bigint pk | |
| account_id | fk | |
| symbol | string(20) | XAUUSD, EURUSD |
| direction | enum(buy,sell) | |
| lot | decimal(10,2) null | |
| entry_price / sl_price / tp_price / exit_price | decimal(18,5) null | |
| pnl | decimal(18,2) null | hasil akhir dalam mata uang akun; null = masih open |
| pips | decimal(10,1) null | |
| rr_planned | decimal(6,2) null | dihitung: \|entry−tp\| / \|entry−sl\| |
| rr_realized | decimal(6,2) null | |
| status | enum(open,win,loss,be) | derived saat simpan |
| opened_at | datetime | |
| closed_at | datetime null | |
| setup | string(50) null | nama strategi/setup |
| tags | json null | |
| notes | text null | |
| source | enum(manual,ai) default manual | |
| ai_raw | json null | output mentah Gemini — satu-satunya jejak isi screenshot |
| timestamps | | |

Index: `(account_id, opened_at)`, `(account_id, status)`, `(account_id, symbol)`

### account_rules  (1 baris per akun, kolom eksplisit — bukan key-value)
`account_id pk fk`
`max_daily_loss decimal(18,2) null`, `max_daily_loss_pct decimal(5,2) null`
`daily_profit_target decimal(18,2) null`, `daily_profit_target_pct decimal(5,2) null`
`max_total_loss_pct decimal(5,2) null`   (mis. batas drawdown 10%)
`max_risk_per_trade_pct decimal(5,2) null`
`max_trades_per_day tinyint null`
`min_rr decimal(4,2) null`
`allowed_sessions json null`  (["london","newyork"])
`notes longtext null`         (markdown bebas — checklist & aturan naratif)

> Semua ini **catatan + indikator**, tidak memblokir input. Aplikasi hanya
> menampilkan status "sisa jatah loss hari ini" dan menandai trade yang melanggar.

### ai_analyses  (cache, biar tidak bayar Gemini berulang)
`id, account_id, period_start date, period_end date, stats_hash char(40),
result_md longtext, model string, created_at`
Unique: `(account_id, stats_hash)`

**Tidak ada tabel ledger/snapshot saldo.** Saldo & equity curve dihitung on-the-fly:
`initial_balance + Σdeposit − Σwithdrawal + Σpnl(closed)`, di-`UNION ALL` dari
`transactions` + `trades` lalu running-sum. Untuk skala pribadi (ribuan baris)
ini instan. Tambah tabel snapshot kalau nanti benar-benar lambat.

---

## 5. Halaman & rute

| Rute | Halaman | Isi |
|---|---|---|
| `/login` | Login | fullscreen, tanpa header |
| `/register` | Daftar | fullscreen, tanpa header |
| `/profile` | Profil | ubah nama/email/sandi · hapus akun pengguna + semua datanya |
| `/accounts` | Daftar akun | kartu per akun: saldo, P/L total, winrate. Tombol buat akun |
| `/` | Dashboard | akun aktif (dari session) |
| `/trades` | Tabel trade | filter symbol/status/tanggal, sort, paginate |
| `/trades/create` | Form manual | |
| `/trades/{id}/edit` | Edit | |
| `/calendar` | Kalender P/L | grid bulanan |
| `/transactions` | Deposit / withdrawal | tabel + dialog tambah |
| `/rules` | Aturan trading | form angka + editor markdown |
| `/analysis` | Analisa AI | pilih periode → generate |

**Account switcher** di header (shadcn `Select`), simpan `current_account_id`
di session; semua controller ambil akun dari middleware `SetCurrentAccount`.

### Dashboard
- Baris stat card (`.glass-card .hover-lift`): Saldo Sekarang, Total P/L (+%),
  Winrate, Profit Factor, Max Drawdown, Rata-rata RR.
- **Equity curve** — line chart, sumbu X tanggal, Y balance. Garis gold.
  Marker cyan di titik deposit/withdrawal. Toggle: balance vs P/L kumulatif.
- Bar chart P/L per bulan (hijau/merah).
- `RuleStatusBanner`: "Loss hari ini −$120 dari batas −$200 · sisa $80" dengan
  progress bar. Merah kalau terlampaui.
- Tabel 10 trade terakhir.

### Kalender
Grid CSS 7 kolom, dibuat manual (komponen `Calendar` shadcn itu date-picker,
tidak cocok). Tiap sel:
- Angka tanggal + total P/L hari itu + jumlah trade.
- Background `success/.12` atau `destructive/.12` sesuai hasil, intensitas
  opacity mengikuti besar P/L (heatmap ringan).
- Titik gold kecil kalau ada pelanggaran aturan hari itu.
- Klik → dialog berisi daftar trade hari tersebut.
Kolom ringkasan mingguan di kanan. Navigasi bulan prev/next.

### Aturan
Dua bagian: (a) form angka yang mengisi `account_rules` — dipakai untuk
perhitungan banner & penandaan; (b) textarea markdown bebas untuk aturan
naratif ("jangan entry saat news merah", checklist pre-trade). Render markdown
pakai style `.rte-content` dari nfp.

---

## 6. Alur AI (Gemini)

Satu service `App\Services\Gemini` dengan dua method. Pakai HTTP client Laravel
langsung ke REST API Gemini — tidak perlu SDK.

### 6.1 Import dari screenshot

```
Upload gambar (drag & drop / paste)
  → Gemini generateContent: [inline_data(image), prompt]
     dengan responseMimeType=application/json + responseSchema
  → JSON: {is_trade_screenshot, symbol, direction, entry, sl, tp, lot,
           exit, pnl, opened_at, closed_at, setup, notes, low_confidence_fields}
  → verifikasi di server (lihat di bawah)
  → buka TradeForm ter-prefill, field dari AI diberi badge gold "AI"
     + gambar tampil di sisi kanan untuk verifikasi mata
  → user koreksi → Simpan (source=ai, ai_raw=respons mentah)
```

- **Gambar tidak disimpan.** Dibaca dari memori, dikirim ke Gemini, lalu dilepas —
  satu-satunya jejak yang tersisa adalah `ai_raw` milik trade. Jurnal ini bisa
  berisi ribuan trade; menyimpan tiap screenshot akan menggelembungkan storage
  tanpa memberi nilai baru.
- **Sinkron** (bukan queue). 1 user, ~3–8 detik, cukup dialog loading.
- **Verifikasi berlapis** supaya gambar sembarangan tidak lolos:
  1. `is_trade_screenshot = false` → ditolak (422), form tidak diisi sama sekali.
  2. `symbol`, `direction`, atau `entry_price` kosong → ditolak (422) dengan
     menyebut field mana yang tidak terbaca.
  3. Yang lolos tetap melewati `TradeRequest` yang sama persis dengan input
     manual — termasuk cek sisi SL/TP terhadap arah posisi.
- Field yang tidak yakin dikembalikan `null` — model diinstruksikan tidak menebak.
  Yang diragukan dicantumkan di `low_confidence_fields` dan ditandai di form.
- `closed_at` ikut diminta ke model. Kalau posisi sudah punya `pnl` tetapi waktu
  tutup tidak terbaca, server mengisinya dengan `opened_at` — kosongnya field ini
  membuat trade tertahan aturan validasi `required_with`.
- Gagal parse / API error → pesan di dialog, form manual tetap tersedia.
- **Input manual selalu tersedia** sebagai jalur utama; AI cuma pengisi awal.

### 6.2 Analisa trading

```
Pilih periode (bulan ini / 30 hari / kustom)
  → AccountStats::summary($account, $from, $to) menghasilkan JSON:
     winrate, profit factor, expectancy, avg win/loss, max DD, streak
     terpanjang, breakdown per symbol / per hari / per jam / per setup,
     distribusi RR, daftar pelanggaran aturan
  → hash(stats) → cek ai_analyses; kalau ada, tampilkan cache
  → kalau belum: kirim stats + isi account_rules ke Gemini (text-only)
     minta markdown: pola menang/kalah, kepatuhan aturan, 3 rekomendasi konkret
  → simpan & render
```

Yang dikirim ke Gemini hanya **angka agregat + teks aturan**. Bukan gambar,
bukan tabel mentah — lebih murah, lebih fokus, dan statistik dihitung di SQL
(deterministik) bukan oleh model.

Kunci API disimpan terenkripsi di tabel `gemini_keys` (dikelola di `/admin`),
boleh lebih dari satu dan dipakai bergantian dengan jeda 10 detik per kunci.
Nama model tetap di `config/services.php`.

---

## 7. Docker

`compose.yml`:

```yaml
services:
  app:                    # frankenphp + octane, serve :80 sekaligus PHP
    build: .
    ports: ["8000:80"]
    volumes: [".:/app"]
    depends_on: [mysql]
    env_file: .env
  mysql:
    image: mysql:8.4
    environment: {MYSQL_DATABASE: trade_history, MYSQL_ROOT_PASSWORD: secret}
    volumes: ["dbdata:/var/lib/mysql"]
    ports: ["3306:3306"]
  vite:                   # dev only
    image: node:22-alpine
    working_dir: /app
    command: sh -c "npm install && npm run dev -- --host"
    ports: ["5173:5173"]
    volumes: [".:/app", "/app/node_modules"]
volumes: {dbdata: {}}
```

`Dockerfile` multi-stage dari `dunglas/frankenphp:php8.4`:
- stage `base`: ekstensi (`pdo_mysql`, `intl`, `gd`, `zip`, `opcache`) + composer
- stage `dev`: `--watch` Octane, `XDG` cache, source di-bind-mount
- stage `build`: `composer install --no-dev -o` + `npm ci && npm run build`
- stage `prod`: hasil build saja, `php artisan octane:frankenphp --workers=2`

Catatan Octane: hindari state di properti singleton; `AccountStats` bikin
stateless. Kalau ada yang aneh, `--max-requests=250`.

---

## 8. Urutan pengerjaan

1. **Fondasi** — Laravel 13 + Inertia + Tailwind v4 + shadcn-vue + font +
   token warna + `AppLayout` (header, ornamen, tab bar mobile). Docker jalan.
2. **Akun & uang** — model `Account`, `Transaction`, CRUD, halaman `/accounts`,
   account switcher, perhitungan saldo.
3. **Trade manual** — CRUD trade, tabel, filter. Ini inti aplikasi.
4. **Visual** — equity chart, stat card, kalender P/L.
5. **Aturan** — `account_rules`, form, `RuleStatusBanner`, penandaan pelanggaran.
6. **AI import** — `Gemini::extractTrade()`, dialog upload, prefill form.
7. **AI analisa** — `AccountStats::summary()`, `Gemini::analyze()`, cache.

Fase 1–3 sudah bisa dipakai harian. 4–7 penambah nilai, tidak memblokir.

---

## 9. Catatan

- Satu-satunya berkas yang disimpan adalah bukti deposit/withdrawal, di disk
  **private**, disajikan lewat route ber-`auth` + cek kepemilikan. Jangan
  `storage:link` ke public. Screenshot trade tidak pernah menyentuh disk.
- PWA: `public/manifest.webmanifest` + `public/sw.js` tulis tangan. Service worker
  hanya meng-cache `/build/`, `/icons/`, dan favicon (nama berisi hash), sedangkan
  seluruh HTML dan request Inertia langsung ke jaringan — jadi tidak ada risiko
  halaman basi. Ikon dibuat ulang lewat `python3 scripts/make-icons.py`.
- Semua uang `decimal`, jangan `float`.
- Timezone: `APP_TIMEZONE=Asia/Jakarta`, waktu disimpan langsung dalam zona itu.
  Untuk satu pengguna di satu zona ini menghapus seluruh kelas bug batas hari
  pada kalender dan aturan harian. `config/app.php` diubah agar membaca env.
- Nilai `rr_planned` dihitung otomatis dari entry/sl/tp saat simpan.

---

## 10. Deviasi saat implementasi

Empat hal berubah dari rancangan awal, semuanya sudah tercermin di tabel & bagian di atas:

| Rencana | Jadinya | Alasan |
|---|---|---|
| Chart pakai shadcn-vue `Chart*` (unovis) | `EquityChart.vue` & `MonthlyPnlChart.vue`, SVG murni | `chart-line` / `chart-bar` tidak ada di registry shadcn-vue; SVG ±150 baris, nol dependensi, tooltip penuh kendali |
| Font via `@fontsource` | `bunny()` dari `laravel-vite-plugin/fonts` + `@fonts` di blade | fitur bawaan Laravel 13, dua dependensi npm hilang, tetap self-hosted |
| Simpan UTC, tampilkan Jakarta | simpan langsung waktu Jakarta | satu pengguna satu zona; menghapus kelas bug batas hari |
| — | TypeScript dipatok `^5.9` | TS 7 (port Go) belum punya API yang dibutuhkan `@vue/compiler-sfc` untuk resolusi tipe lintas file di Vite 8 |

Vite 8 juga butuh dua baris tambahan di `vite.config.ts` (`registerTS` + `script.fs`)
supaya compiler SFC bisa membaca tipe props dari reka-ui.

---

## 11. Revisi setelah pemakaian pertama

| Perubahan | Alasan |
|---|---|
| Mata uang akun jadi pilihan `USD` / `USC` / `IDR` | akun sen (USC) bukan kode ISO 4217, jadi `Intl.NumberFormat` diberi jalur khusus di `money()` |
| Screenshot trade tidak lagi disimpan | ribuan trade × satu gambar = storage membengkak tanpa nilai tambah; gambar hanya perlu hidup selama form terbuka |
| Bukti transfer wajib untuk deposit/withdrawal | ini catatan uang sungguhan, bukan tebakan — satu-satunya berkas yang memang layak disimpan |
| `closed_at` ikut diminta ke Gemini + fallback ke `opened_at` | field ini selalu kosong lewat jalur AI, lalu trade tertahan validasi `required_with` |
| Verifikasi `is_trade_screenshot` + field inti | mencegah gambar sembarangan diproses dan mengisi form dengan data setengah jadi |
| Analisa AI dipatok ≤200 kata & empat bagian tetap | keluaran panjang tidak dibaca ulang |
| Register + hapus akun pengguna | sebelumnya user hanya bisa dibuat lewat seeder |
| PWA (manifest, service worker, ikon) | dipakai dari HP sambil trading, jadi harus bisa dipasang di home screen |
| `env_file: .env` dilepas dari service `app` di compose | variabel proses menimpa `$_ENV` milik phpunit, sehingga `php artisan test` berjalan sebagai `local` dan kena CSRF |

---

## 12. Revisi kedua

| Perubahan | Alasan |
|---|---|
| `price()` di `useFormat.ts` untuk harga instrumen | `decimal(18,5)` selalu mengembalikan 5 desimal (`4404.51000`); nol di ujung tidak membawa informasi |
| Kolom RR menampilkan R hasil **dan** R rencana | posisi yang kena SL/TP persis membuat R hasil selalu tepat −1,00R atau sama dengan R rencana — barisnya jadi tidak bercerita apa-apa |
| `ai_raw` akhirnya benar-benar disimpan | dokumen ini menyebutnya "satu-satunya jejak isi screenshot", tapi tidak ada satu baris pun yang menulisnya: `TradeRequest` tidak memvalidasinya sehingga selalu terbuang |
| Prompt: `exit_price` tidak boleh menyalin S/L atau T/P | mencegah model menebak harga penutupan dari level order yang terlihat di layar |
| Service worker didaftarkan di dev juga | dijaga `import.meta.env.PROD`, jadi tidak pernah aktif dan browser tidak pernah menawarkan "Install" |
| Menu "Pasang aplikasi" + `manifest.id` | tawaran bawaan browser mudah terlewat; iOS bahkan tidak punya `beforeinstallprompt` sama sekali |
| `vite` pindah ke `node:24-slim`, `restart: "no"`, jalan sebagai UID host | `npm run build` selesai lalu keluar (loop restart tanpa henti); kontainer root membuat `public/build` tidak bisa dibersihkan dari host; volume bernama selalu lahir milik root |
| Healthcheck `app` memakai `/up` | healthcheck bawaan image FrankenPHP memakai endpoint admin yang dimatikan di Caddyfile, jadi container selalu "unhealthy" |

---

## 13. Revisi ketiga (review fitur)

| Perubahan | Alasan |
|---|---|
| `/profile` minta sandi sekarang saat mengganti sandi atau email | tanpa itu satu sesi yang terlanjur dibajak cukup untuk mengunci pemiliknya sendiri di luar; ganti nama tetap tidak diminta. Sandi baru sekaligus mematikan sesi di perangkat lain |
| `violations()` tidak lagi menanyakan saldo per hari | `balance()` dipanggil di dalam loop, dua query tiap hari, bahkan saat batas loss harian tidak diisi. Saldo pembukaan sekarang ditelusuri sekali dari kurva ekuitas: 300 hari aktif turun dari **611 query jadi 10** |
| `equityCurve()` disimpan di properti objek | dihitung tiga kali per muat Dashboard (langsung, lewat `maxDrawdown()`, lewat `peakBalance()`) padahal isinya sama |
| `max_risk_per_trade_pct` dan `allowed_sessions` akhirnya dinilai | keduanya bisa diisi di /rules lalu tidak pernah dibaca satu baris pun. Risiko dinilai dari kerugian yang benar-benar terjadi terhadap saldo pembukaan hari itu; sesi dari jam `opened_at` |
| `min_rr` ikut tampil di banner harian | aturannya sudah dinilai di kalender, tapi tidak pernah muncul di halaman yang dilihat tiap hari |
| Kolom `pips` dan `tags` dihapus | `pips` tidak pernah diisi jalur simpan mana pun; `tags` divalidasi dan ditampilkan tapi tidak punya field di form — penandaan strategi sudah dikerjakan `setup` |
| `Transaction::signedAmount()`, `Account::ruleOrNew()`, dan suite `Unit` di phpunit.xml dihapus | nol pemanggil; direktori `tests/Unit` yang tidak ada membuat `php artisan test` gagal sebelum satu tes pun jalan |
| Dashboard "10 trade terakhir" ikut `COALESCE(closed_at, opened_at)` | satu-satunya tempat yang masih mengurut `opened_at`, jadi daftarnya bisa berbeda dari baris teratas /trades |


---

## 14. Laporan tahunan untuk pajak

Fitur ini tidak ada di rancangan awal. Pemicunya di luar aplikasi: perlu satu berkas
yang bisa diserahkan saat pajak meminta klarifikasi penghasilan dari trading.

| Perubahan | Alasan |
|---|---|
| `AnnualReport` + `resources/views/reports/annual.blade.php` → PDF A4 landscape | seluruh angkanya sudah ada di `AccountStats`; yang belum ada cuma bentuk yang bisa diserahkan ke orang lain. Service mengembalikan array polos supaya angkanya bisa diuji tanpa membongkar byte PDF |
| `dompdf/dompdf`, bukan Browsershot/Snappy | container `app` punya `dom`, `mbstring`, `gd`, tapi tidak punya Chromium, Node, maupun satu pun font sistem. dompdf jalan tanpa mengubah Dockerfile dan memakai font DejaVu bawaannya |
| Nomor halaman lewat `page_text()` di controller, bukan `counter(pages)` di CSS | dompdf menghitung counter saat menyusun tata letak, ketika jumlah halaman belum diketahui — hasilnya selalu "dari 0". API kanvas mengisinya setelah dokumen jadi, tanpa perlu menyalakan `isPhpEnabled` |
| Drawdown diukur di kurva trading (`tradingCurve()`), bukan kurva saldo | setor/tarik menggerakkan saldo sama persis dengan laba/rugi, jadi menarik untung ke bank terbaca sebagai penurunan terdalam dan menyetor modal terbaca sebagai pemulihan. Keduanya bukan kinerja trading. Berlaku untuk `max_drawdown` di laporan/dashboard/analisa maupun `drawdown_pct` yang menilai `max_total_loss_pct` |
| Id baris keluar sebagai hashids (`App\Support\Hashid`), digarami APP_KEY | id berurutan terbaca dari luar, dan tautan bukti ikut tercetak di dokumen pajak yang berpindah tangan. Didekode di satu tempat — `Route::bind` di `AppServiceProvider`, tempat kepemilikan sudah dicek. Hash bukan izin: pagarnya tetap `where user_id`. Ganti APP_KEY = tautan lama mati, sama seperti URL bertanda tangan |
| `monthlyPnl()` dapat parameter `$endingAt` | jangkarnya `now()` mati, jadi tidak bisa melayani tahun pajak yang sudah lewat |
| `AccountStats::trades()` jadi publik | lampiran butuh barisnya satu per satu; tanpa ini `COALESCE(closed_at, opened_at)` jadi salinan ketiga |
| Laporan menarik akun langsung dari tabel, bukan dari `$request->accountList()` | middleware itu membuang akun arsip, padahal trade tahun itu tetap penghasilan tahun itu — laporannya akan mengecilkan angka |
| Setor/tarik memakai `rate_idr` masing-masing baris, laba/rugi memakai satu kurs tahunan | mutasi dana punya kurs hari transaksinya dan ada bukti transfernya; laba/rugi trading tidak punya kurs per transaksi. Bedanya dinyatakan di catatan kaki laporan, bukan disamarkan |
| Unduhan lewat `<form method="POST">` biasa, bukan `useForm().post()` | Inertia tidak bisa menerima respons biner. Karena itu `csrf` ikut dibagikan di `HandleInertiaRequests` — NPWP tidak perlu menginap di query string dan log akses |
| `by_setup` tidak dipakai di laporan | trade bertag `"BOS, FVG"` masuk dua bucket sehingga jumlahnya melebihi total transaksi — aman untuk evaluasi strategi, menyesatkan di dokumen pajak |
| PDF memakai Helvetica, bukan DejaVu | font inti PDF: tidak ikut ditanam ke berkas (82 KB → 50 KB) dan metrikanya lebih ramping, jadi lampiran muat 33 baris per halaman, bukan 19. Konsekuensinya `−` (U+2212) diganti `-` biasa karena WinAnsi tidak punya glifnya |
| Kurs wajib disertai tanggal berlakunya | kurs tanpa tanggal tidak bisa diperiksa ulang oleh siapa pun. Tanggalnya ikut bergeser otomatis saat tahun pajak diganti — tanggal tahun lalu yang tersimpan di peramban akan tercetak diam-diam kalau tidak |
| Harga instrumen di lampiran dipangkas nol ekornya | `decimal(18,5)` selalu kembali `4.523,13000`; sama seperti `price()` di useFormat.ts, minimal dua desimal tetap disisakan |
| Bukti dua tahap: `proofs.link` abadi di dokumen, `proofs.view` hidup 60 detik | dompdf menulis anotasi `/URI` sungguhan, jadi bisa diklik dari dalam PDF. Pemegang laporan berhak membuka kapan pun — laporan pajak bisa baru dibaca berbulan-bulan kemudian — jadi tautan di dokumen tidak boleh hangus. Yang berumur pendek alamat hasil lemparannya, yang mendarat di riwayat browser dan gampang tersalin. Kedaluwarsanya ditumpangkan ke tanda tangan berbatas waktu Laravel, jadi tidak ada jam yang perlu disimpan sendiri |
| Kolom kurs menerima koma desimal (`17.757,40`) | `input[type=number]` menolak koma dan `numeric` Laravel menolak `17757,40`. Koma hanya bisa berarti desimal, jadi begitu ia muncul titik pasti pemisah ribuan; tanpa koma angkanya dibiarkan apa adanya. Halaman laporan menampilkan hasil bacaannya kembali supaya salah tafsir ketahuan sebelum PDF diunduh |
| Kurs dicetak dua desimal, bukan lewat `$rp()` | `$rp()` membulatkan ke rupiah penuh, sehingga kurs 17.757,40 tercetak "Rp17.757" dan tidak lagi cocok dengan angka yang dipakai menghitung. Kolom kurs di tabel mutasi kena hal yang sama: `rate_idr` 17.719,64 sempat tampil "Rp17.720" |
| Kop dwibahasa, logo aplikasi, dan warna tema menggantikan abu-abu | dokumen ini diserahkan ke orang lain, jadi harus terlihat sebagai terbitan yang jelas asal-usulnya. Emas `hsl(43 96% 56%)` dan navy tema dipakai apa adanya, digelapkan seperlunya agar terbaca di atas kertas putih |
| Label Indonesia dengan terjemahan Inggris miring di bawahnya | pola lembar resmi bank; sekaligus membuat laporan bisa dibaca kalau sewaktu-waktu diminta dalam bahasa Inggris |
| Watermark ubin digambar GD, ditempel di `body` | dompdf **mengabaikan** `background-image` pada `html` (terbukti: 0 XObject gambar) tapi memasangnya di `body`. Fontnya diambil dari `vendor/dompdf/dompdf/lib/fonts` karena container tidak punya font sistem. Sel data sengaja dibiarkan tembus supaya polanya utuh; hanya kepala tabel yang menutupinya |
| Pernyataan penutup menegaskan dokumen ini terbitan sendiri | laporan meniru struktur formal lembar rekening koran, jadi harus eksplisit menyatakan bukan terbitan bank/broker/instansi. Kejujuran itu yang membuatnya dipercaya, bukan sebaliknya |
| Catatan angka & pernyataan jadi butir bernomor dwibahasa, tanpa tanda pisah | permintaan langsung: tanda `—` dihapus dari seluruh kalimat laporan dan halaman /reports |
| Kolom `accounts.account_number` ditambahkan | laporan ini catatan sendiri, jadi kekuatannya bergantung pada bisa-tidaknya dicocokkan ke statement resmi broker. Nomor akun adalah satu-satunya penanda yang menyambungkan keduanya; tanpa itu pemeriksa tidak bisa memastikan dua dokumen membicarakan akun yang sama |
| Tabel pendek diberi `page-break-inside: avoid` | dompdf mengulang `<thead>` saat tabel terbelah, kecuali kalau baris badan pertamanya sudah tidak muat di halaman yang sama — barisnya lalu lahir tanpa kepala. Lampiran sengaja dibiarkan terbelah, di sana pengulangannya jalan |
