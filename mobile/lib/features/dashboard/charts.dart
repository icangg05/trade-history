import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/stats.dart';
import '../../widgets/common.dart';

/// Label sumbu grafik ikut ukuran huruf sistem sampai 130%, lalu berhenti:
/// grafik tidak bisa mengalir ulang seperti teks, dan angka lengkapnya ada di
/// tooltip serta ringkasan untuk pembaca layar. Ruang sumbu dihitung dari
/// skala yang sama, jadi labelnya tidak meluap.
TextScaler _axisScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

/// Kurva perkembangan akun. `pnl = true` menampilkan P/L kumulatif: saldo
/// dikurangi saldo awal dan seluruh setoran/penarikan, supaya deposit tidak
/// terbaca sebagai profit. Titik cyan menandai hari dengan arus dana.
class EquityChart extends StatelessWidget {
  const EquityChart({
    super.key,
    required this.points,
    required this.currency,
    this.pnl = false,
    this.height = 240,
  });

  final List<EquityPoint> points;
  final String currency;
  final bool pnl;
  final double height;

  List<double> get _series =>
      pnl ? cumulativePnl(points) : [for (final point in points) point.balance];

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Caption('Belum cukup data untuk digambar di periode ini.'),
        ),
      );
    }

    final start = points.first.date;
    final xs = [
      for (final point in points) point.date.difference(start).inHours / 24,
    ];
    final ys = _series;

    // Sumbu selalu memuat nol — sama seperti web — lalu dibulatkan keluar ke
    // langkah "bulat" supaya labelnya 0 / 10k / 20k, bukan 10.2k / 19.1k.
    // Garis yang persis menyentuh batas diberi satu langkah ruang.
    final yMin = math.min(ys.reduce(math.min), 0.0);
    final yMax = math.max(ys.reduce(math.max), 0.0);
    final span = (yMax - yMin) == 0
        ? (yMax.abs() == 0 ? 1.0 : yMax.abs())
        : yMax - yMin;
    final step = niceStep(span / 3);
    var lo = (yMin / step).floor() * step;
    var hi = (yMax / step).ceil() * step;
    if (yMin < 0 && yMin - lo < step * .05) lo -= step;
    if (yMax > 0 && hi - yMax < step * .05) hi += step;
    if (hi == lo) hi = lo + step;
    final xMax = xs.last == 0 ? 1.0 : xs.last;

    final flows = {
      for (var i = 0; i < points.length; i++)
        if (points[i].flow != 0) xs[i],
    };

    String dateAt(double x) => DateFormat(
      'd MMM',
      'id_ID',
    ).format(start.add(Duration(hours: (x * 24).round())));

    final axis = _axisScaler(context);
    final low = ys.reduce(math.min);
    final high = ys.reduce(math.max);

    return Semantics(
      label:
          '${pnl ? 'Grafik P/L kumulatif' : 'Grafik saldo'} ${dateAt(0)} sampai '
          '${dateAt(xMax)}: dari ${money(ys.first, currency)} ke '
          '${money(ys.last, currency)}, terendah ${money(low, currency)}, '
          'tertinggi ${money(high, currency)}.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: xMax,
            minY: lo,
            maxY: hi,
            clipData: const FlClipData.all(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.border,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: axis.scale(11) * 4.2,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      compact(value),
                      textScaler: axis,
                      style: mono(size: 11, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: axis.scale(11) * 1.4 + 6,
                  interval: xMax / 2,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child: Text(
                      dateAt(value),
                      textScaler: axis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.popover,
                tooltipBorder: const BorderSide(color: AppColors.border),
                tooltipBorderRadius: BorderRadius.circular(8),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    _tooltip(points[spots.first.spotIndex], spot.y),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++) FlSpot(xs[i], ys[i]),
                ],
                color: AppColors.gold,
                barWidth: 2,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  applyCutOffY: true,
                  cutOffY: math.max(lo, 0),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.gold.withValues(alpha: .28),
                      AppColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  checkToShowDot: (spot, _) => flows.contains(spot.x),
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 2,
                        color: AppColors.cyan,
                        strokeWidth: 1,
                        strokeColor: AppColors.background,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineTooltipItem _tooltip(EquityPoint point, double value) => LineTooltipItem(
    '${longDate(point.date)}\n',
    const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
    children: [
      TextSpan(
        text: money(value, currency, signed: pnl),
        style: mono(
          size: 12.5,
          weight: FontWeight.w600,
          color: AppColors.foreground,
        ),
      ),
      if (point.pnl != 0)
        TextSpan(
          text: '\nTrading ${money(point.pnl, currency, signed: true)}',
          style: mono(size: 11, color: pnlColor(point.pnl)),
        ),
      if (point.flow != 0)
        TextSpan(
          text:
              '\n${point.flow > 0 ? 'Deposit' : 'Withdrawal'} ${money(point.flow.abs(), currency)}',
          style: mono(size: 11, color: AppColors.cyan),
        ),
    ],
  );
}

/// P/L kumulatif per titik: saldo dikurangi saldo pembuka dan seluruh
/// setoran/penarikan sejauh itu. Saldo pembuka diambil sebelum titik pertama
/// bergerak — titik pertama akun tanpa modal awal adalah deposit pertamanya,
/// dan deposit itu bukan profit.
List<double> cumulativePnl(List<EquityPoint> points) {
  final first = points.first;
  final base = first.balance - first.pnl - first.flow;
  var flow = 0.0;

  return [
    for (final point in points) point.balance - base - (flow += point.flow),
  ];
}

/// Langkah sumbu yang "bulat": 1, 2, atau 5 dikali pangkat sepuluh.
double niceStep(double raw) {
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final n = raw / magnitude;

  return (n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10))) * magnitude;
}

/// Satuan batang grafik P/L periode, ikut panjang periodenya supaya jumlah
/// batangnya tetap terbaca: 30 hari per hari, 90 hari per minggu, setahun per
/// bulan, lebih dari dua tahun per tahun.
enum PnlStep {
  day('per hari'),
  week('per minggu'),
  month('per bulan'),
  year('per tahun');

  const PnlStep(this.label);

  final String label;
}

class PnlBar {
  const PnlBar(this.start, this.pnl);

  /// Hari pertama batang ini: Senin untuk minggu, tanggal 1 untuk bulan.
  final DateTime start;
  final double pnl;
}

/// P/L per batang, dijumlah dari titik kurva ekuitas (sudah per hari) mulai
/// titik pertamanya sampai [to]. Rentang tanpa trade tetap jadi batang nol.
(PnlStep, List<PnlBar>) pnlBars(List<EquityPoint> points, DateTime to) {
  if (points.isEmpty) return (PnlStep.day, const []);

  final from = points.first.date;
  final days = to.difference(from).inDays;
  final step = days <= 31
      ? PnlStep.day
      : days <= 120
      ? PnlStep.week
      : days <= 730
      ? PnlStep.month
      : PnlStep.year;

  DateTime floor(DateTime date) => switch (step) {
    PnlStep.day => DateTime(date.year, date.month, date.day),
    PnlStep.week => DateTime(
      date.year,
      date.month,
      date.day - date.weekday + 1,
    ),
    PnlStep.month => DateTime(date.year, date.month),
    PnlStep.year => DateTime(date.year),
  };

  DateTime next(DateTime date) => switch (step) {
    PnlStep.day => DateTime(date.year, date.month, date.day + 1),
    PnlStep.week => DateTime(date.year, date.month, date.day + 7),
    PnlStep.month => DateTime(date.year, date.month + 1),
    PnlStep.year => DateTime(date.year + 1),
  };

  final sums = <DateTime, double>{};
  for (final point in points) {
    sums.update(
      floor(point.date),
      (sum) => sum + point.pnl,
      ifAbsent: () => point.pnl,
    );
  }

  final end = floor(to);

  return (
    step,
    [
      for (var at = floor(from); !at.isAfter(end); at = next(at))
        PnlBar(at, sums[at] ?? 0),
    ],
  );
}

/// P/L periode yang dipilih: batang hijau ke atas, merah ke bawah dari garis
/// nol, plus total bersih, persen terhadap saldo awal periode, dan
/// profit/loss kotor — angka yang sama dengan kartu P/L periode.
///
/// Kolom yang sedang ditekan disorot (batang lain meredup), dan tooltip-nya
/// muncul di separuh grafik yang tidak disentuh supaya tidak tertutup jari.
class PeriodPnlChart extends StatefulWidget {
  const PeriodPnlChart({super.key, required this.data});

  final Dashboard data;

  @override
  State<PeriodPnlChart> createState() => _PeriodPnlChartState();
}

class _PeriodPnlChartState extends State<PeriodPnlChart> {
  /// Kolom yang sedang ditekan, dan apakah jarinya di separuh atas.
  (int, bool)? _touch;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final summary = data.summary;
    final currency = summary.currency;
    final (unit, bars) = pnlBars(data.equity, summary.to);

    if (bars.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(child: Caption('Belum ada data di periode ini.')),
      );
    }

    final values = [for (final bar in bars) bar.pnl];
    final high = values.fold(0.0, math.max);
    final low = values.fold(0.0, math.min);
    final step = niceStep((high - low) / 4 == 0 ? 1 : (high - low) / 4);

    var top = (high / step).ceil() * step;
    var bottom = (low / step).floor() * step;
    if (top == bottom) (top, bottom) = (step, -step);

    final net = summary.netPnl;
    final change = data.growthPct;
    final axis = _axisScaler(context);
    // Paling banyak enam label di sumbu bawah: 31 batang harian tidak muat.
    final every = (bars.length / 6).ceil();

    String format(String pattern, DateTime date) =>
        DateFormat(pattern, 'id_ID').format(date);

    String title(DateTime start) => switch (unit) {
      PnlStep.day => longDate(start),
      PnlStep.week =>
        '${format('d MMM', start)} – ${longDate(DateTime(start.year, start.month, start.day + 6))}',
      PnlStep.month => format('MMMM y', start),
      PnlStep.year => '${start.year}',
    };

    // Baris kedua (bulan / tahun) hanya di label pertama dan saat berganti.
    (String, String?) tick(int index) {
      final start = bars[index].start;
      final previous = index == 0 ? null : bars[index - every].start;

      return switch (unit) {
        PnlStep.day || PnlStep.week => (
          '${start.day}',
          previous?.month == start.month ? null : format('MMM', start),
        ),
        PnlStep.month => (
          format('MMM', start),
          previous == null || start.month == 1
              ? "'${'${start.year}'.substring(2)}"
              : null,
        ),
        PnlStep.year => ('${start.year}', null),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                money(net, currency, signed: true),
                style: mono(
                  size: 19,
                  weight: FontWeight.w600,
                  color: pnlColor(net),
                ),
              ),
            ),
            if (change != null)
              Tooltip(
                message:
                    'P/L dibagi saldo awal periode ditambah deposit selama periode',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (change >= 0
                                ? AppColors.success
                                : AppColors.destructive)
                            .withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: onTint(
                          change >= 0
                              ? AppColors.success
                              : AppColors.destructive,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        pct(change, 2),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: onTint(
                            change >= 0
                                ? AppColors.success
                                : AppColors.destructive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Caption('Batang ${unit.label}'),
        const SizedBox(height: 14),
        Semantics(
          label:
              'Grafik P/L ${unit.label}: ${[for (final bar in bars) '${title(bar.start)} ${money(bar.pnl, currency, signed: true)}'].join(', ')}.',
          excludeSemantics: true,
          child: SizedBox(
            height: 170,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Batang mengisi 70% jatahnya, di luar sumbu kiri: 31 batang
                // harian tetap muat, 3 batang bulanan tidak jadi lidi.
                final slot =
                    (constraints.maxWidth - axis.scale(11) * 3.6) / bars.length;
                final width = (slot * .7).clamp(3.0, 32.0);
                final touched = _touch?.$1;
                final upper = _touch?.$2 ?? false;

                return BarChart(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  BarChartData(
                    minY: bottom,
                    maxY: top,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: step,
                      getDrawingHorizontalLine: (value) =>
                          value.abs() < step / 1000
                          ? const FlLine(
                              color: AppColors.border,
                              strokeWidth: 1,
                            )
                          : FlLine(
                              color: AppColors.border.withValues(alpha: .45),
                              strokeWidth: 1,
                              dashArray: const [3, 3],
                            ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: axis.scale(11) * 3.6,
                          interval: step,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              compact(value),
                              textScaler: axis,
                              style: mono(
                                size: 11,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          // Dua baris label + jarak 4.
                          reservedSize: axis.scale(11) * 1.5 * 2 + 6,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();

                            if (index % every != 0) return const SizedBox();

                            final (main, sub) = tick(index);

                            return SideTitleWidget(
                              meta: meta,
                              space: 4,
                              child: Column(
                                children: [
                                  for (final text in [main, ?sub])
                                    Text(
                                      text,
                                      textScaler: axis,
                                      style: mono(
                                        size: 11,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Seluruh kolom bisa disentuh, bukan hanya batangnya: jalur
                    // latar setinggi grafik, dan celah antarbatang dibagi dua
                    // ke kiri-kanan. Batang harian cuma beberapa px lebarnya.
                    barTouchData: BarTouchData(
                      allowTouchBarBackDraw: true,
                      touchExtraThreshold: EdgeInsets.symmetric(
                        horizontal: math.max(0, (slot - width) / 2),
                      ),
                      touchCallback: (event, response) {
                        final spot = response?.spot;
                        final next =
                            event.isInterestedForInteractions && spot != null
                            ? (
                                spot.touchedBarGroupIndex,
                                response!.touchChartCoordinate.dy >
                                    (top + bottom) / 2,
                              )
                            : null;

                        if (next != _touch) setState(() => _touch = next);
                      },
                      touchTooltipData: BarTouchTooltipData(
                        // Di separuh yang tidak disentuh: margin sebesar ini
                        // melewati tepi grafik, lalu `fitInsideVertically`
                        // menempelkannya di tepi atas atau bawah.
                        direction: upper
                            ? TooltipDirection.bottom
                            : TooltipDirection.top,
                        tooltipMargin: 1000,
                        getTooltipColor: (_) => AppColors.popover,
                        tooltipBorder: const BorderSide(
                          color: AppColors.border,
                        ),
                        tooltipBorderRadius: BorderRadius.circular(8),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                          '${title(bars[group.x].start)}\n',
                          const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                          children: [
                            TextSpan(
                              text: money(rod.toY, currency, signed: true),
                              style: mono(
                                size: 12,
                                weight: FontWeight.w600,
                                color: pnlColor(rod.toY),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < bars.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: bars[i].pnl,
                              width: width,
                              color:
                                  (bars[i].pnl >= 0
                                          ? AppColors.success
                                          : AppColors.destructive)
                                      .withValues(
                                        alpha: touched == null
                                            ? .75
                                            : i == touched
                                            ? 1
                                            : .35,
                                      ),
                              borderRadius: BorderRadius.circular(2),
                              // Jalur samar di tiap slot: hari tanpa trade
                              // tetap terlihat, grafik tidak bolong. Arahnya
                              // harus searah batang: fl_chart memakai `fromY`
                              // jalur sebagai pangkal area sentuh, jadi jalur
                              // yang berlawanan arah membuat kolom batang merah
                              // tidak bisa disentuh (tooltip tidak muncul).
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                fromY: bars[i].pnl >= 0 ? bottom : top,
                                toY: bars[i].pnl >= 0 ? top : bottom,
                                color: i == touched
                                    ? AppColors.foreground.withValues(alpha: .1)
                                    : AppColors.border.withValues(alpha: .3),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 24),
        _legend(AppColors.success, 'Profit', summary.grossProfit, currency),
        const SizedBox(height: 4),
        _legend(AppColors.destructive, 'Loss', -summary.grossLoss, currency),
      ],
    );
  }

  Widget _legend(Color color, String label, double value, String currency) =>
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Caption(label),
          const Spacer(),
          Text(
            money(value, currency, signed: true),
            style: mono(size: 12, color: color),
          ),
        ],
      );
}
