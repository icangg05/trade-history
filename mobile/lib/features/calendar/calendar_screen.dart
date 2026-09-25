import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/stats.dart';
import '../../models/trade.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/trade_widgets.dart';
import '../trades/trade_detail.dart';

final calendarProvider = FutureProvider.autoDispose
    .family<CalendarMonth, (int, String)>((ref, key) {
      ref.watch(revisionProvider);

      return ref.watch(journalProvider).calendar(key.$1, key.$2);
    });

const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Arah geser terakhir: bulan baru masuk dari sisi seberang geseran.
  int _direction = 1;

  void _shift(int offset) => setState(() {
    _direction = offset.sign;
    _month = DateTime(_month.year, _month.month + offset);
  });

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: monthLabel(isoMonth(_month)),
    loading: const _Skeleton(),
    actions: (_) => [
      IconButton(
        tooltip: 'Bulan sebelumnya',
        onPressed: () => _shift(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      // Ikon, bukan tulisan "Bulan ini": di layar 360 dp tulisan itu
      // memotong judul bulannya sendiri jadi "September …".
      IconButton(
        tooltip: 'Bulan ini',
        onPressed: () => setState(
          () => _month = DateTime(DateTime.now().year, DateTime.now().month),
        ),
        icon: const Icon(Icons.today_outlined),
      ),
      IconButton(
        tooltip: 'Bulan berikutnya',
        onPressed: () => _shift(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
    body: (context, account) {
      final key = (account.id, isoMonth(_month));

      return GestureDetector(
        // Geser kiri/kanan untuk ganti bulan, seperti di web.
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;

          if (velocity.abs() > 250) _shift(velocity < 0 ? 1 : -1);
        },
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(calendarProvider(key).future),
          child: AnimatedSwitcher(
            // Animasi dimatikan di ponsel: bulan langsung berganti, tanpa
            // geser.
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                begin: Offset(
                  child.key == ValueKey(key)
                      ? _direction * .25
                      : -_direction * .25,
                  0,
                ),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: KeyedSubtree(
              key: ValueKey(key),
              child: AsyncView(
                value: ref.watch(calendarProvider(key)),
                onRetry: () => ref.invalidate(calendarProvider(key)),
                loading: const _Skeleton(),
                builder: (data) => _content(data, account),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _content(CalendarMonth data, AccountBrief account) {
    final totals = data.monthTotal.values;
    final pnl = totals.fold(0.0, (sum, day) => sum + day.pnl);
    final trades = totals.fold(0, (sum, day) => sum + day.trades);
    final green = totals.where((day) => day.pnl > 0).length;
    final red = totals.where((day) => day.pnl < 0).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text.rich(
            TextSpan(
              text: money(pnl, account.currency, signed: true),
              style: mono(
                size: 15,
                weight: FontWeight.w600,
                color: pnlColor(pnl),
              ),
              children: [
                TextSpan(
                  text: '  ·  $trades trade · $green hari hijau / $red merah',
                  style: const TextStyle(
                    fontFamily: kSans,
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.all(8),
          child: _Grid(
            data: data,
            onSelect: (date) => _openDay(data, date, account),
          ),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Caption(
            'Titik emas di pojok sel menandai hari yang melanggar aturan akun ini. Geser untuk ganti bulan.',
          ),
        ),
      ],
    );
  }

  void _openDay(CalendarMonth data, String date, AccountBrief account) =>
      showModalBottomSheet<void>(
        context: context,
        // Menutupi tab bar juga, sama seperti modal di web.
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .95,
          builder: (sheet, scroll) => _DaySheet(
            date: date,
            stat: data.days[date],
            violations: data.violations[date] ?? const [],
            trades: data.trades[date] ?? const [],
            account: account,
            scroll: scroll,
          ),
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.data, required this.onSelect});

  final CalendarMonth data;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = isoDate(DateTime.now());
    final maxAbs = data.days.values.fold(
      1.0,
      (value, day) => math.max(value, day.pnl.abs()),
    );
    final days = <DateTime>[
      for (
        var day = data.gridStart;
        !day.isAfter(data.gridEnd);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        day,
    ];

    // Tinggi sel: bentuk tegak di layar tegak, lebih landai saat layar
    // melebar (ponsel miring, tablet) supaya sebulan muat tanpa menggulir.
    // Itu tinggi minimum — satu minggu ikut meninggi bila isi selnya butuh
    // lebih (huruf sistem yang besar), alih-alih teksnya meluap.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight =
            (constraints.maxWidth / 7 - 4) / (landscape ? 1.6 : .82);

        return Column(
          children: [
            const _Weekdays(),
            for (var week = 0; week < days.length / 7; week++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in days.skip(week * 7).take(7))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _Cell(
                            day: day,
                            stat: data.days[isoDate(day)],
                            inMonth: isoMonth(day) == data.month,
                            today: isoDate(day) == today,
                            flagged: data.violations.containsKey(isoDate(day)),
                            maxAbs: maxAbs,
                            minHeight: minHeight,
                            onTap: () => onSelect(isoDate(day)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Weekdays extends StatelessWidget {
  const _Weekdays();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final name in _weekdays)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            // "Kam" tidak pecah jadi "Ka / m" saat huruf sistem besar.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Ringkasan bulan, kisi tanggal (nama harinya sudah pasti, selnya menyusul),
/// lalu keterangan di bawahnya.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => SkeletonView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Bone(width: 220, height: 14),
      ),
      Panel(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const _Weekdays(),
            for (var week = 0; week < 5; week++)
              Row(
                children: [
                  for (var day = 0; day < 7; day++)
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: AspectRatio(
                          aspectRatio: .82,
                          child: Bone(radius: 7),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SkeletonLines(lines: 2),
      ),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.stat,
    required this.inMonth,
    required this.today,
    required this.flagged,
    required this.maxAbs,
    required this.minHeight,
    required this.onTap,
  });

  final double minHeight;
  final DateTime day;
  final DayStat? stat;
  final bool inMonth;
  final bool today;
  final bool flagged;
  final double maxAbs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stat = this.stat;

    // Warna sel: hijau/merah dengan opasitas mengikuti besar P/L (heatmap ringan).
    final hue = stat == null || stat.pnl == 0
        ? null
        : (stat.pnl > 0 ? AppColors.success : AppColors.destructive);
    final heat =
        hue?.withValues(alpha: .1 + stat!.pnl.abs() / maxAbs * .28) ??
        Colors.transparent;
    // Di atas sel berwarna teksnya ikut terang, supaya tetap terbaca di hari
    // untung/rugi terbesar — justru hari yang paling ingin dibaca.
    final secondary = hue == null
        ? AppColors.mutedForeground
        : AppColors.mutedOnTint;

    return Opacity(
      opacity: inMonth ? 1 : .35,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Material(
          color: heat,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(
              color: today
                  ? AppColors.gold.withValues(alpha: .7)
                  : (inMonth ? AppColors.border : Colors.transparent),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: stat == null ? null : onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: mono(size: 11, color: secondary),
                      ),
                      const Spacer(),
                      if (stat != null) ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            compact(stat.pnl, signed: true),
                            style: mono(
                              size: 11,
                              weight: FontWeight.w600,
                              color: hue == null
                                  ? AppColors.success
                                  : onTint(hue),
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${stat.wins}W/${stat.losses}L',
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (flagged)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.date,
    required this.stat,
    required this.violations,
    required this.trades,
    required this.account,
    required this.scroll,
  });

  final String date;
  final DayStat? stat;
  final List<String> violations;
  final List<Trade> trades;
  final AccountBrief account;
  final ScrollController scroll;

  /// Trade dikelompokkan menurut hari tutupnya, jadi jam bukanya bisa jatuh di
  /// hari sebelumnya — saat itu tanggalnya ikut ditulis singkat.
  String _opened(Trade trade) => isoDate(trade.openedAt) == date
      ? clock(trade.openedAt)
      : '${DateFormat('dd/MM').format(trade.openedAt)} ${clock(trade.openedAt)}';

  @override
  Widget build(BuildContext context) {
    final stat = this.stat;
    final lots = trades.fold(0.0, (sum, trade) => sum + (trade.lot ?? 0));
    final winRate = stat == null || stat.trades == 0
        ? null
        : stat.wins / stat.trades * 100;
    final currency = account.currency;

    Widget figure(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Caption(label), const SizedBox(height: 2), value],
    );

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          longDate(DateTime.parse(date)),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        // Dua kolom, bukan empat: P/L dalam mata uang lengkap tidak muat di
        // seperempat lebar ponsel.
        if (stat != null)
          StatGrid(
            children: [
              figure(
                'P/L hari ini',
                Text(
                  money(stat.pnl, currency, signed: true),
                  style: mono(size: 13, color: pnlColor(stat.pnl)),
                ),
              ),
              figure(
                'Trade',
                Text(
                  '${stat.trades}  ${stat.wins}W/${stat.losses}L',
                  style: mono(size: 13),
                ),
              ),
              figure(
                'Winrate',
                Text(
                  winRate == null ? '—' : pct(winRate, 0),
                  style: mono(size: 13),
                ),
              ),
              figure('Total lot', Text(number(lots), style: mono(size: 13))),
            ],
          ),
        if (violations.isNotEmpty) ...[
          const SizedBox(height: 14),
          Notice(child: Text(violations.join(' · '))),
        ],
        const SizedBox(height: 12),
        if (trades.isEmpty)
          const EmptyState(message: 'Tidak ada trade tertutup di hari ini.')
        else
          for (var i = 0; i < trades.length; i++) ...[
            if (groupGap(trades, i)) const SizedBox(height: 6),
            DecoratedBox(
              decoration: groupFrame(trades, i) ?? const BoxDecoration(),
              child: TradeRow(
                trade: trades[i],
                currency: currency,
                subtitle: [
                  _opened(trades[i]),
                  if ((trades[i].setup ?? '').isNotEmpty) trades[i].setup!,
                  '${number(trades[i].lot)} lot',
                ].join(' · '),
                trailingBelow: rr(trades[i].rrRealized),
                onTap: () => showTradeDetail(
                  context,
                  account: account.id,
                  currency: currency,
                  trade: trades[i],
                ),
              ),
            ),
            if (rowDivider(trades, i)) const Divider(indent: 10, endIndent: 10),
          ],
      ],
    );
  }
}
