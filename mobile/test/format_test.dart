import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/core/format.dart';

import 'support.dart';

/// Bentuk angka harus sama dengan `useFormat.ts` di web — angka yang sama
/// tidak boleh terbaca berbeda di browser dan di ponsel.
void main() {
  setUpAll(setUpFormatting);

  test('uang mengikuti Intl id-ID web, termasuk akun sen', () {
    expect(money(1234.5, 'USD'), 'US\$1.234,50');
    expect(money(1234567, 'IDR'), 'Rp 1.234.567');
    expect(money(3700, 'USC'), '3.700,00 USC');
    expect(money(-20, 'USD'), '-US\$20,00');
    expect(money(null, 'USD'), '—');
  });

  test('uang bertanda memakai minus tipografis dan plus eksplisit', () {
    expect(money(-20, 'USD', signed: true), '−US\$20,00');
    expect(money(20, 'USD', signed: true), '+US\$20,00');
    expect(money(0, 'USD', signed: true), 'US\$0,00');
  });

  test('harga membuang nol di ujung tapi menyisakan dua desimal', () {
    expect(price(4404.51), '4.404,51');
    expect(price(2369.71434), '2.369,71434');
    expect(price(1.1), '1,10');
  });

  test('angka pendek untuk sel kalender', () {
    expect(compact(15300), '15.3k');
    expect(compact(-1234), '−1.23k');
    expect(compact(500, signed: true), '+500');
  });

  test('tanggal dan jam gaya Indonesia', () {
    final value = DateTime(2026, 3, 5, 14, 5);

    expect(longDate(value), '5 Maret 2026');
    expect(clock(value), '14.05');
    expect(dateTime(value), '5 Maret 2026, 14.05');
    expect(monthLabel('2026-03'), 'Maret 2026');
    expect(isoMinute(value), '2026-03-05T14:05');
  });

  test('waktu server dibaca sebagai jam dinding, dengan atau tanpa offset', () {
    expect(wallTime('2026-09-24T18:24'), DateTime(2026, 9, 24, 18, 24));
    expect(
      wallTime('2026-09-24T18:24:00+08:00'),
      DateTime(2026, 9, 24, 18, 24),
    );
    expect(wallTime('2026-01-01'), DateTime(2026));
  });

  test('isian angka menerima koma desimal seperti ReportController', () {
    expect(parseDecimal('17.757,40'), 17757.40);
    expect(parseDecimal('2412.35'), 2412.35);
    expect(parseDecimal(' 1500 '), 1500);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('abc'), isNull);
  });

  test('angka kembali ke isian tanpa nol di ujung', () {
    expect(inputNumber(1500), '1500');
    expect(inputNumber(0.05), '0.05');
    expect(inputNumber(null), '');
  });

  test('kurs akun sen dihitung per 1/100 dolar', () {
    expect(toIdr(3700, 16000, 'USC'), 592000);
    expect(toIdr(37, 16000, 'USD'), 592000);
    expect(rateCurrency('USC'), 'USD');
  });
}
