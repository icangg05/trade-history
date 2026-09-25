import 'package:flutter/painting.dart' show Color;
import 'package:intl/intl.dart';

import 'theme.dart';

/// Padanan `resources/js/composables/useFormat.ts`: bentuk angka dan tanggal
/// di aplikasi harus sama dengan di browser, sampai ke tanda minusnya.

const _locale = 'id_ID';

const currencies = <(String, String)>[
  ('USD', 'USD — Dolar AS'),
  ('USC', 'USC — Sen dolar (akun cent)'),
  ('IDR', 'IDR — Rupiah'),
];

const _digits = {'USD': 2, 'USC': 2, 'IDR': 0};

String _fixed(double value, int digits) => NumberFormat(
  digits == 0 ? '#,##0' : '#,##0.${'0' * digits}',
  _locale,
).format(value);

/// Uang lengkap dengan mata uang akun: `US$1.234,50`, `Rp 1.234.567`,
/// `3.700,00 USC`. USC (akun sen) bukan kode ISO 4217, jadi diberi akhiran.
///
/// `signed` memakai tanda minus tipografis (−) dan plus eksplisit, sama seperti
/// web; tanpa `signed` minusnya tanda hubung biasa.
String money(double? value, String currency, {bool signed = false}) {
  if (value == null) return '—';

  final amount = _fixed(value.abs(), _digits[currency] ?? 2);
  final text = switch (currency) {
    'USC' => '$amount USC',
    'IDR' => 'Rp $amount',
    'USD' => 'US\$$amount',
    _ => '$currency $amount',
  };

  if (!signed) return value < 0 ? '-$text' : text;

  return value < 0 ? '−$text' : (value > 0 ? '+$text' : text);
}

/// Nilai rupiah dari nominal akun. Kurs selalu dicatat per dolar, sedangkan
/// akun sen dinyatakan dalam 1/100 dolar — 3700 USC = $37, bukan $3700.
double? toIdr(double? amount, double? rate, String currency) {
  if (amount == null || rate == null) return null;

  return currency == 'USC' ? amount * rate / 100 : amount * rate;
}

/// Mata uang yang kursnya dipakai: akun sen memakai kurs dolar induknya.
String rateCurrency(String currency) => currency == 'USC' ? 'USD' : currency;

String number(double? value, [int digits = 2]) =>
    value == null ? '—' : _fixed(value, digits);

/// Harga instrumen: presisi mengikuti angkanya, bukan lebar kolom database.
/// `decimal(18,5)` selalu kembali lima desimal; nol di ujungnya dibuang.
String price(double? value) =>
    value == null ? '—' : NumberFormat('#,##0.00###', _locale).format(value);

/// Angka pendek untuk sel sempit kalender: 1.2k / 15m, tanpa mata uang.
String compact(double? value, {bool signed = false}) {
  if (value == null) return '—';

  final text = (NumberFormat.compact(
    locale: 'en_US',
  )..significantDigits = 3).format(value.abs()).toLowerCase();

  return value < 0 ? '−$text' : (signed && value > 0 ? '+$text' : text);
}

String pct(double? value, [int digits = 1]) =>
    value == null ? '—' : '${number(value, digits)}%';

String rr(double? value) => value == null ? '—' : '${number(value)}R';

/// "5 Maret 2026".
String longDate(DateTime? value) =>
    value == null ? '—' : DateFormat('d MMMM y', _locale).format(value);

/// "14.05".
String clock(DateTime? value) =>
    value == null ? '—' : DateFormat('HH.mm', _locale).format(value);

/// "5 Maret 2026, 14.05".
String dateTime(DateTime? value) =>
    value == null ? '—' : '${longDate(value)}, ${clock(value)}';

/// "5 Mar 2026, 14.05" — untuk sel setengah lebar yang tidak muat nama bulan penuh.
String shortDateTime(DateTime? value) => value == null
    ? '—'
    : '${DateFormat('d MMM y', _locale).format(value)}, ${clock(value)}';

/// "2026-03" → "Maret 2026".
String monthLabel(String month) =>
    DateFormat('MMMM y', _locale).format(DateTime.parse('$month-01'));

/// "2026-03" → "Mar".
String shortMonth(String month) =>
    DateFormat('MMM', _locale).format(DateTime.parse('$month-01'));

/// Hijau untung, merah rugi, abu netral.
Color pnlColor(double? value) {
  if (value == null || value == 0) return AppColors.mutedForeground;

  return value > 0 ? AppColors.success : AppColors.destructive;
}

// ------------------------------------------------------------------ tanggal

/// Server menyimpan waktu dalam zona APP_TIMEZONE dan mengirimnya kadang tanpa
/// offset (`2026-09-24T18:24`), kadang dengan (`…T18:24:00+08:00`). Keduanya
/// dibaca sebagai jam dinding server — satu pengguna, satu zona — supaya jam
/// yang tampil tidak bergeser hanya karena ponselnya sedang di zona lain.
DateTime wallTime(String value) =>
    DateTime.parse(value.length > 19 ? value.substring(0, 19) : value);

DateTime? wallTimeOrNull(Object? value) =>
    value is String && value.isNotEmpty ? wallTime(value) : null;

/// Titik waktu sungguhan (mis. `updated_at` dalam UTC): ditampilkan di zona ponsel.
DateTime? instantOrNull(Object? value) => value is String && value.isNotEmpty
    ? DateTime.parse(value).toLocal()
    : null;

String isoDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

String isoMonth(DateTime value) => DateFormat('yyyy-MM').format(value);

/// Bentuk yang dikirim ke server untuk kolom datetime — sama dengan
/// `input[type=datetime-local]` di web.
String isoMinute(DateTime value) =>
    DateFormat("yyyy-MM-dd'T'HH:mm").format(value);

// ------------------------------------------------------------------- isian

/// Angka dari kolom isian. Koma hanya bisa berarti desimal, jadi begitu ia
/// muncul titik pasti pemisah ribuan (`17.757,40`) — aturan yang sama dengan
/// `ReportController::decimal()` di server.
double? parseDecimal(String? raw) {
  final text = (raw ?? '').trim().replaceAll(' ', '');

  if (text.isEmpty) return null;

  return double.tryParse(
    text.contains(',') ? text.replaceAll('.', '').replaceAll(',', '.') : text,
  );
}

/// Kebalikannya: angka untuk mengisi ulang kolom isian, tanpa nol di ujung.
String inputNumber(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }

  return value.toString();
}
