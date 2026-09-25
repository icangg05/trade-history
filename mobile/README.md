# Trade History — mobile

Versi Android & iOS dari jurnal trading ini, ditulis dengan **Flutter 3.47** (Dart 3.13).
Aplikasi ini hanya klien: seluruh angka — saldo, winrate, drawdown, pelanggaran aturan —
tetap dihitung server lewat controller yang sama dengan halaman web, jadi apa yang tampil
di ponsel selalu sama persis dengan di browser.

## Menjalankan

Butuh Flutter 3.47+ dan server Trade History yang sudah punya API mobile
(`routes/api.php`, lihat README di akar repo).

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulator Android → host
```

`API_BASE_URL` hanya isian awal layar masuk; alamat server bisa diganti dari sana dan
diingat di perangkat. Tanpa skema, `https://` yang dipakai.

| Perintah | Guna |
|---|---|
| `flutter test` | uji model, format angka, dan seluruh layar (360 px) dengan jawaban server rekaman |
| `flutter analyze` | lint (`flutter_lints`) |
| `flutter build apk --release --dart-define=API_BASE_URL=https://…` | APK rilis |
| `flutter build ipa --dart-define=API_BASE_URL=https://…` | iOS (butuh macOS + Xcode) |
| `dart run flutter_launcher_icons` | buat ulang ikon dari `assets/icon/` (disalin dari `public/icons/`) |

Build rilis Android masih ditandatangani dengan kunci debug (bawaan `flutter create`).
Sebelum dibagikan, pasang keystore sendiri di `android/app/build.gradle.kts`.

## Paket

| Paket | Dipakai untuk |
|---|---|
| `flutter_riverpod` 3 | state: sesi, akun aktif, data tiap layar (`FutureProvider.family` per akun) |
| `go_router` 18 | navigasi; `StatefulShellRoute` untuk tab bar bawah |
| `dio` 5 | HTTP + multipart (screenshot AI, bukti transfer) + unduhan PDF |
| `flutter_secure_storage` | token Sanctum di Keychain / Keystore |
| `shared_preferences` | alamat server, akun terakhir, riwayat chat AI, isian laporan |
| `fl_chart` | kurva ekuitas & grafik P/L bulanan |
| `flutter_markdown_plus` | catatan aturan & jawaban AI |
| `image_picker` | kamera / galeri untuk screenshot trade dan bukti transfer |
| `share_plus` + `path_provider` | menyimpan / membagikan PDF laporan tahunan |
| `intl` + `flutter_localizations` | angka & tanggal gaya `id-ID`, date picker berbahasa Indonesia |

Font IBM Plex Sans & Mono dibundel di `assets/fonts` (SIL Open Font License 1.1,
© IBM Corp.), bukan diunduh saat jalan.

## Peta kode

```
lib/core/        theme (token warna web), format (padanan useFormat.ts), api_client, json
lib/data/        session (token, akun aktif, revisi data), journal_api (semua endpoint)
lib/models/      bentuk JSON dari server
lib/widgets/     Panel, StatCard, TradeRow, bingkai grup, pengalih akun, dll.
lib/features/    satu folder per layar — dashboard, trades, calendar, transactions,
                 rules, analysis (+ chat), accounts, reports, profile, auth, more
test/fixtures/   jawaban API sungguhan (php artisan serve + DemoSeeder)
```

## Catatan

- **Tidak ada angka yang dihitung ulang di ponsel.** Satu-satunya hitungan lokal adalah
  umpan balik form (RR rencana, sisi TP/SL) — nilai yang tersimpan tetap dari server.
- **Satu revisi, semua layar segar.** Setiap simpan/hapus menaikkan `revisionProvider`;
  dashboard, kalender, daftar trade, dana, dan aturan menontonnya, jadi tidak ada yang
  basi setelah trade baru dicatat.
- **Waktu dibaca sebagai jam dinding server** (`wallTime()`), karena server menyimpan
  dalam zona `APP_TIMEZONE` — jam trade tidak bergeser saat ponsel di zona lain.
- **Hapus uang pakai kode.** Transaksi dana dan akun trading hanya bisa dihapus setelah
  mengetik ulang kode empat angka, sama seperti `ConfirmDestroy.vue`.
- **Masih `package:flutter/material.dart`, belum `material_ui`.** Flutter 3.44+ memisahkan
  Material ke paket `material_ui`, dan go_router 18 sudah pindah — tapi fl_chart dan
  flutter_markdown_plus belum. Karena itu tiap rute memakai `pageBuilder` dengan
  `MaterialPage` (lihat `lib/app.dart`); tanpa itu go_router tidak mengenali MaterialApp
  dan semua perpindahan layar tampil tanpa animasi.
- Pesan galat validasi bawaan Laravel diterjemahkan di `validationMessage()`: server
  belum punya `lang/id/validation.php`, jadi pesannya keluar sebagai kunci
  (`validation.required`).
