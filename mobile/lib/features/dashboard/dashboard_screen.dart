import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/session.dart';
import '../../models/stats.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/rule_status_card.dart';
import '../../widgets/trade_widgets.dart';
import '../trades/trade_detail.dart';
import 'charts.dart';

const periods = [
  ('30d', '30 hari'),
  ('90d', '90 hari'),
  ('1y', '1 tahun'),
  ('all', 'Semua'),
];

final dashboardProvider = FutureProvider.autoDispose
    .family<Dashboard, (int, String)>((ref, key) {
      ref.watch(revisionProvider);

      return ref.watch(journalProvider).dashboard(key.$1, key.$2);
    });

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _range = '30d';
  bool _cumulative = false;

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Dashboard',
    actions: (_) => [
      IconButton(
        tooltip: 'Trade baru',
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => context.push('/trade/new'),
      ),
    ],
    body: (context, account) {
      final key = (account.id, _range);

      return RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider(key).future),
        child: AsyncView(
          value: ref.watch(dashboardProvider(key)),
          onRetry: () => ref.invalidate(dashboardProvider(key)),
          builder: (data) => _content(data, account.id),
        ),
      );
    },
  );

  Widget _content(Dashboard data, int account) {
    final summary = data.summary;
    final currency = summary.currency;

    return ListView(
      scrollCacheExtent: kWholePageCache,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Caption('${longDate(summary.from)} — ${longDate(summary.to)}'),
        const SizedBox(height: 10),
        Segments(
          value: _range,
          options: periods,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 14),
        StatGrid(
          children: [
            StatCard(
              label: 'Saldo',
              value: money(summary.balance, currency),
              hint: 'Modal ${money(summary.initialBalance, currency)}',
              tone: Tone.gold,
            ),
            StatCard(
              label: 'P/L periode',
              value: money(summary.netPnl, currency, signed: true),
              hint: 'Pertumbuhan ${pct(data.growthPct)}',
              tone: summary.netPnl >= 0 ? Tone.good : Tone.bad,
            ),
            StatCard(
              label: 'Winrate',
              value: pct(summary.winRate),
              hint:
                  '${summary.wins}W / ${summary.losses}L / ${summary.breakeven}BE',
            ),
            StatCard(
              label: 'Profit factor',
              value: summary.profitFactor == null
                  ? '—'
                  : number(summary.profitFactor),
              hint:
                  'Ekspektasi ${money(summary.expectancy, currency, signed: true)}',
              tone: (summary.profitFactor ?? 0) >= 1 ? Tone.good : Tone.bad,
            ),
            StatCard(
              label: 'Max drawdown',
              value: money(summary.maxDrawdown, currency),
              hint: pct(summary.maxDrawdownPct),
              tone: Tone.bad,
            ),
            StatCard(
              label: 'Rata-rata RR',
              value: rr(summary.avgRrRealized),
              hint: summary.avgRrPlanned == null
                  ? null
                  : 'Rencana ${rr(summary.avgRrPlanned)}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Perkembangan akun',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segments(
                value: _cumulative,
                options: const [(false, 'Saldo'), (true, 'P/L kumulatif')],
                onChanged: (value) => setState(() => _cumulative = value),
              ),
              const SizedBox(height: 14),
              EquityChart(
                points: data.equity,
                currency: currency,
                pnl: _cumulative,
              ),
              const SizedBox(height: 6),
              const Caption(
                'Titik cyan menandai hari dengan deposit atau withdrawal.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RuleStatusCard(status: data.ruleStatus, currency: currency),
        const SizedBox(height: 14),
        Panel(
          title: 'P/L per bulan',
          child: MonthlyPnlChart(
            data: data.monthly,
            currency: currency,
            base: data.monthlyBase,
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Trade terakhir',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          trailing: TextButton(
            onPressed: () => context.go('/trades'),
            child: const Text('Lihat semua'),
          ),
          child: data.recent.isEmpty
              ? const EmptyState(message: 'Belum ada trade.')
              : Column(
                  children: [
                    for (var i = 0; i < data.recent.length; i++) ...[
                      if (groupGap(data.recent, i)) const SizedBox(height: 6),
                      DecoratedBox(
                        decoration:
                            groupFrame(data.recent, i) ?? const BoxDecoration(),
                        child: TradeRow(
                          trade: data.recent[i],
                          currency: currency,
                          subtitle: dateTime(data.recent[i].openedAt),
                          onTap: () => showTradeDetail(
                            context,
                            account: account,
                            currency: currency,
                            trade: data.recent[i],
                          ),
                        ),
                      ),
                      if (rowDivider(data.recent, i))
                        const Divider(indent: 10, endIndent: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
