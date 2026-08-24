# Trade History

Jurnal trading pribadi: multi-akun, tiap akun punya riwayat, arus dana, dan aturan sendiri.
Input trade bisa manual atau diisi otomatis dari screenshot lewat Gemini.

Rancangan lengkap ada di [RANCANGAN.md](RANCANGAN.md).

## Stack

Laravel 13 · Inertia 3 + Vue 3 (TS) · Tailwind CSS 4 · shadcn-vue · MySQL 8.4 ·
FrankenPHP (+ Octane di produksi) · Gemini `gemini-3.5-flash` · PWA

Tema **dark saja** — palet diambil dari blok `.dark` project `nfp`, di-flatten ke `:root`
di [resources/css/app.css](resources/css/app.css). Tidak ada toggle terang/gelap.
Font IBM Plex Sans + IBM Plex Mono, di-self-host otomatis oleh `laravel-vite-plugin`.

## Menjalankan

```bash
cp .env.example .env                    # tidak ada kunci API di sini — semua di database
docker compose up -d                    # app :8000, mysql :3306, vite :5173
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
docker compose exec app php artisan db:seed              # buat user admin dari SEED_USER_* di .env
docker compose exec app php artisan db:seed --class=DemoSeeder   # opsional: data contoh
```

Buka <http://localhost:8000> dan login dengan `SEED_USER_EMAIL` / `SEED_USER_PASSWORD`.

Tanpa Docker (butuh PHP 8.3+, Composer, Node 22+, MySQL):

```bash
composer install && npm install
php artisan key:generate && php artisan migrate && php artisan db:seed
npm run dev            # terminal 1
php artisan serve      # terminal 2
```

## Perintah harian

| Perintah | Guna |
|---|---|
| `docker compose exec app php artisan test` | jalankan test |
| `docker compose exec app ./vendor/bin/pint` | rapikan gaya PHP |
| `npm run build` | build aset produksi |
| `docker compose exec app php artisan db:seed --class=DemoSeeder` | isi ulang data contoh |
| `python3 scripts/make-icons.py` | buat ulang ikon PWA (butuh Pillow) |

Container `app` berjalan dalam mode klasik FrankenPHP, jadi perubahan kode PHP langsung
terpakai tanpa restart. Produksi memakai stage `production` di `Dockerfile` (Octane
worker mode).

## Peta kode

```
app/Services/AccountStats.php    semua agregasi: saldo, kurva ekuitas, winrate,
                                 profit factor, drawdown, breakdown, pelanggaran aturan
app/Services/Gemini.php          extractTrade() dari gambar · analyze() dari statistik
app/Services/Uploads.php         simpan bukti transfer di disk privat
app/Models/Trade.php             rr_planned / rr_realized / status diturunkan saat simpan
resources/js/pages/              Dashboard, Trades, Calendar, Transactions, Rules,
                                 Analysis, Accounts, Profile, Login, Register
resources/js/components/         EquityChart & MonthlyPnlChart (SVG murni), PnlCalendar,
                                 RuleStatusBanner, AiImportDialog
public/manifest.webmanifest      PWA
public/sw.js                     service worker (cache aset build saja)
scripts/make-icons.py            generator ikon PWA
```

## Catatan penting

- **Aturan trading tidak memblokir apa pun.** Halaman Aturan hanya catatan + indikator:
  sisa jatah loss hari ini, penanda hari yang melanggar. Trade tetap bisa dicatat.
- **Statistik dihitung di SQL, bukan oleh AI.** Yang dikirim ke Gemini hanya angka
  agregat + teks aturan, jadi angkanya deterministik dan biayanya kecil.
- **Hasil AI diperlakukan seperti input pengguna biasa** — lewat validasi
  `TradeRequest` yang sama, termasuk cek sisi SL/TP terhadap arah posisi.
- **Screenshot trade tidak disimpan.** Gambar dibaca sekali oleh Gemini lalu dilepas;
  yang tersisa hanya hasil bacaannya di kolom `ai_raw`. Ribuan trade × satu gambar
  bukan sesuatu yang perlu ditanggung penyimpanan.
- **Bukti transfer deposit/withdrawal wajib** dan memang disimpan, di
  `storage/app/private/proofs/{akun}/`, hanya keluar lewat
  `/transactions/{id}/proof` setelah kepemilikan dicek. Folder `storage/app`
  di-bind ke disk host lewat `compose.yml` (`./storage/app:/app/storage/app`), jadi
  berkasnya tidak ikut hilang saat kontainer dibangun ulang. Kontainer dev berjalan
  sebagai user host (`user: "${UID:-1000}:${GID:-1000}"`) supaya berkas unggahan
  dimiliki user yang sama di kedua sisi — bisa dibuka dan dihapus tanpa sudo.
- **Dua peran, tidak saling menyentuh.** Admin mengurus pengguna, kunci Gemini, dan
  cadangan database di `/admin` — dan tidak bisa membuka satu pun halaman trading.
  Trader hanya punya jurnalnya sendiri.
- **Tidak ada kunci API di `.env`.** Kunci Gemini, nama model, dan batas kuotanya
  hidup di tabel `gemini_settings`, terenkripsi, diatur admin lewat `/admin`.
- **Pendaftaran mandiri dijaga token.** `/register` hanya menerima pendaftar yang
  tahu `REGISTER_TOKEN` di `.env`; dikosongkan, halaman daftarnya tidak ada sama
  sekali dan tautannya hilang dari halaman masuk.
- **Import AI diverifikasi dua lapis** sebelum menyentuh form: gambar harus benar-benar
  layar trading (`is_trade_screenshot`), dan simbol + arah + harga entry harus terbaca.
  Yang lolos tetap melewati `TradeRequest` yang sama dengan input manual.
- **Mata uang akun terbatas pada USD, USC (akun sen), dan IDR.** USC bukan kode
  ISO 4217, jadi `money()` memformatnya sebagai angka + akhiran kode.
- **PWA**: `public/manifest.webmanifest` + `public/sw.js`. Service worker hanya
  meng-cache aset ber-hash (`/build/`, `/icons/`); semua HTML dan request Inertia
  langsung ke jaringan, jadi tidak ada halaman basi. Didaftarkan di dev maupun
  produksi — tanpa service worker aktif browser tidak pernah menawarkan "Install".
  Selain tawaran bawaan browser, ada menu **Pasang aplikasi** di dropdown profil
  (di iOS menampilkan petunjuk Bagikan → Tambahkan ke Layar Utama).
- **Harga ditampilkan tanpa nol berlebih.** Kolom `decimal(18,5)` selalu
  mengembalikan 5 desimal; `price()` di `useFormat.ts` memangkasnya
  (4404.51000 → `4.404,51`).
- **`compose.yml` sengaja tidak memakai `env_file`** untuk service `app` — Laravel
  sudah membaca `/app/.env` dari bind mount, dan menyuntikkannya sebagai variabel
  proses membuat `php artisan test` berjalan sebagai `local` (lalu kena CSRF).
- **Service `vite` memakai `node:24-slim` (glibc) dan berbagi `node_modules`
  dengan host**, bukan Alpine + volume terpisah: binari native (rolldown) harus
  cocok dengan libc host, dan volume bernama selalu lahir milik root sehingga
  kontainer non-root tidak bisa menulis ke sana.
- **Waktu disimpan dalam zona `APP_TIMEZONE`** (default `Asia/Jakarta`), bukan UTC, supaya
  batas "hari trading" di kalender dan aturan harian tidak meleset beberapa jam.
- **Tidak ada tabel snapshot saldo.** Saldo dan kurva ekuitas dihitung ulang dari
  `trades` + `transactions` setiap request.
