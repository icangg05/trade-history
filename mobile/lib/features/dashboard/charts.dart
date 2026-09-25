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
/// dikurangi modal awal dan seluruh setoran/penarikan, supaya deposit tidak
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

  List<double> get _series {
    if (!pnl) return [for (final point in points) point.balance];

    final base = points.first.balance;
    var flow = 0.0;

    return [
      for (final point in points) point.balance - base - (flow += point.flow),
    ];
  }

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
                        radius: 3.5,
                        color: AppColors.cyan,
                        strokeWidth: 1.5,
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

/// Langkah sumbu yang "bulat": 1, 2, atau 5 dikali pangkat sepuluh.
double niceStep(double raw) {
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final n = raw / magnitude;

  return (n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10))) * magnitude;
}

/// P/L per bulan: batang hijau ke atas, merah ke bawah dari garis nol, plus
/// total bersih, persen terhadap saldo awal jendela, dan profit/loss kotor.
class MonthlyPnlChart extends StatelessWidget {
  const MonthlyPnlChart({
    super.key,
    required this.data,
    required this.currency,
    this.base,
  });

  final List<MonthlyPnl> data;
  final String currency;

  /// Saldo di awal jendela 12 bulan; null = badge persen disembunyikan.
  final double? base;

  @override
  Widget build(BuildContext context) {
    final values = [for (final item in data) item.pnl];
    final high = values.fold(0.0, math.max);
    final low = values.fold(0.0, math.min);
    final step = niceStep((high - low) / 4 == 0 ? 1 : (high - low) / 4);

    var top = (high / step).ceil() * step;
    var bottom = (low / step).floor() * step;
    if (top == bottom) (top, bottom) = (step, -step);

    final net = values.fold(0.0, (sum, value) => sum + value);
    final profit = data.fold(0.0, (sum, item) => sum + item.profit);
    final loss = data.fold(0.0, (sum, item) => sum + item.loss);
    final change = base != null && base! > 0 ? net / base! * 100 : null;
    final axis = _axisScaler(context);

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
                message: 'Perubahan terhadap saldo di awal periode 12 bulan',
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
        const SizedBox(height: 16),
        Semantics(
          label:
              'Grafik P/L per bulan: ${[for (final item in data) '${monthLabel(item.month)} ${money(item.pnl, currency, signed: true)}'].join(', ')}.',
          excludeSemantics: true,
          child: SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                minY: bottom,
                maxY: top,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (value) => value.abs() < step / 1000
                      ? const FlLine(color: AppColors.border, strokeWidth: 1)
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
                      // Dua baris label (bulan, lalu tahun) + jarak 4.
                      reservedSize: axis.scale(11) * 1.5 * 2 + 6,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final month = data[index].month;
                        final showYear = index == 0 || month.endsWith('-01');

                        return SideTitleWidget(
                          meta: meta,
                          space: 4,
                          child: Column(
                            children: [
                              Text(
                                shortMonth(month),
                                textScaler: axis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              if (showYear)
                                Text(
                                  "'${month.substring(2, 4)}",
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.popover,
                    tooltipBorder: const BorderSide(color: AppColors.border),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${monthLabel(data[group.x].month)}\n',
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
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].pnl,
                          width: 12,
                          color:
                              (data[i].pnl >= 0
                                      ? AppColors.success
                                      : AppColors.destructive)
                                  .withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 24),
        _legend(AppColors.success, 'Profit', profit),
        const SizedBox(height: 4),
        _legend(AppColors.destructive, 'Loss', loss),
      ],
    );
  }

  Widget _legend(Color color, String label, double value) => Row(
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
