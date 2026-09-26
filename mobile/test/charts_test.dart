import 'package:fl_chart/fl_chart.dart';
// ignore: implementation_imports
import 'package:fl_chart/src/chart/bar_chart/bar_chart_painter.dart';
// ignore: implementation_imports
import 'package:fl_chart/src/chart/bar_chart/bar_chart_renderer.dart';
// ignore: implementation_imports
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trade_history/features/dashboard/charts.dart';
import 'package:trade_history/models/stats.dart';

import 'support.dart';

EquityPoint point(
  String date,
  double pnl, {
  double balance = 0,
  double flow = 0,
}) => EquityPoint(
  date: DateTime.parse(date),
  balance: balance,
  pnl: pnl,
  flow: flow,
);

void main() {
  test('30 hari: batang per hari, hari kosong tetap nol', () {
    final (step, bars) = pnlBars([
      point('2026-09-14', 0),
      point('2026-09-15', 50),
      point('2026-09-17', -20),
    ], DateTime(2026, 9, 18));

    expect(step, PnlStep.day);
    expect([for (final bar in bars) bar.pnl], [0, 50, 0, -20, 0]);
  });

  test('90 hari: dijumlah per minggu mulai Senin', () {
    final (step, bars) = pnlBars([
      point('2026-06-28', 0), // Minggu → minggu Senin 22 Juni
      point('2026-06-29', 10), // Senin
      point('2026-07-05', 5), // Minggu yang sama
    ], DateTime(2026, 9, 26));

    expect(step, PnlStep.week);
    expect(bars.first.start, DateTime(2026, 6, 22));
    expect(bars[1].pnl, 15);
  });

  test('setahun per bulan, lebih dari dua tahun per tahun', () {
    final (month, bars) = pnlBars([
      point('2025-09-26', 0),
      point('2026-01-31', 7),
    ], DateTime(2026, 9, 26));

    expect(month, PnlStep.month);
    expect(bars, hasLength(13));
    expect(bars[4].pnl, 7);

    final (year, _) = pnlBars([point('2023-01-01', 0)], DateTime(2026, 9, 26));
    expect(year, PnlStep.year);
  });

  group('pertumbuhan periode', () {
    test('tanpa arus dana sama dengan P/L ÷ saldo awal', () {
      expect(periodGrowth([point('2026-09-01', 0, balance: 1000)], 100), 10);
    });

    test('deposit ikut jadi modal, withdrawal tidak mengecilkannya', () {
      final growth = periodGrowth([
        point('2026-09-01', 0, balance: 1000),
        point('2026-09-02', 0, balance: 10000, flow: 9000),
        // Profit ditarik: dulu (Dietz) ini menyusutkan dasar sampai ribuan persen.
        point('2026-09-20', 0, balance: 1000, flow: -9000),
      ], 500);

      expect(growth, 500 / 10000 * 100);
    });

    test('trade di hari pertama tidak ikut jadi modal', () {
      expect(periodGrowth([point('2026-09-01', 100, balance: 1100)], 100), 10);
    });

    test('saldo awal 0 memakai setorannya; tanpa dasar → null', () {
      expect(
        periodGrowth([
          point('2026-09-14', 0),
          point('2026-09-15', 0, balance: 1000, flow: 1000),
        ], 50),
        5,
      );
      expect(periodGrowth([point('2026-09-14', 0)], 0), isNull);
    });
  });

  test('P/L kumulatif mulai dari nol walau titik pertama adalah deposit', () {
    expect(
      cumulativePnl([
        point('2026-07-01', 0, balance: 5000, flow: 5000),
        point('2026-07-02', 200, balance: 5200),
        point('2026-07-03', 0, balance: 4200, flow: -1000),
      ]),
      [0, 200, 200],
    );
  });

  // Seluruh kolom bisa disentuh, bukan hanya batangnya: di atas dan di bawah
  // batang (jalur latar), dan di celah antarbatang. Jalur yang arahnya
  // berlawanan dengan batang membuat kolom batang merah mati sentuh.
  testWidgets('tiap kolom P/L periode, hijau maupun merah, bisa disentuh', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeriodPnlChart(data: Dashboard.fromJson(fixture('dashboard'))),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart)).data;
    final painter = BarChartPainter();
    final holder = PaintHolder(chart, chart, TextScaler.noScaling);
    final size = tester.getSize(find.byType(BarChartLeaf));
    final rods = [for (final group in chart.barGroups) group.barRods.single];

    expect(rods.where((rod) => rod.toY < 0), isNotEmpty);

    final touched = <int>{};
    for (var x = 1.0; x < size.width - 1; x++) {
      for (final y in [1.0, size.height / 2, size.height - 1]) {
        final spot = painter.handleTouch(Offset(x, y), size, holder);

        expect(spot, isNotNull, reason: 'x $x, y $y');
        touched.add(spot!.touchedBarGroupIndex);
      }
    }

    expect(touched, {for (var i = 0; i < rods.length; i++) i});
  });

  testWidgets('kolom yang ditekan disorot, tooltip di separuh seberang jari', (
    tester,
  ) async {
    await initializeDateFormatting('id_ID');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeriodPnlChart(data: Dashboard.fromJson(fixture('dashboard'))),
        ),
      ),
    );

    BarChartData chart() => tester.widget<BarChart>(find.byType(BarChart)).data;
    List<double> alphas() => [
      for (final group in chart().barGroups) group.barRods.single.color!.a,
    ];

    final leaf = tester.getRect(find.byType(BarChartLeaf));

    // Separuh bawah: tooltip di atas.
    final gesture = await tester.startGesture(
      Offset(leaf.center.dx, leaf.bottom - 4),
    );
    await tester.pumpAndSettle();

    expect(alphas().where((alpha) => alpha == 1), hasLength(1));
    expect(
      alphas().where((alpha) => alpha < .5),
      hasLength(alphas().length - 1),
    );
    expect(
      chart().barTouchData.touchTooltipData.direction,
      TooltipDirection.top,
    );

    // Separuh atas: tooltip pindah ke bawah.
    await gesture.moveTo(Offset(leaf.center.dx, leaf.top + 4));
    await tester.pumpAndSettle();

    expect(
      chart().barTouchData.touchTooltipData.direction,
      TooltipDirection.bottom,
    );

    // Dilepas: sorotan hilang.
    await gesture.up();
    await tester.pumpAndSettle();

    expect(alphas(), everyElement(closeTo(.75, .01)));
  });
}
