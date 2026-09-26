import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/stats.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/rule_status_card.dart';
import '../../widgets/skeleton.dart';
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

/// Rentang tanggal, periode, kartu angka, kurva, aturan hari ini, grafik
/// P/L periode, trade terakhir — urutan yang sama dengan isinya.
const _loading = SkeletonView(
  children: [
    Bone(width: 180, height: 10),
    SkeletonField(),
    SkeletonStats(count: 6),
    SkeletonPanel(
      child: Column(
        children: [SkeletonField(), SizedBox(height: 14), Bone(height: 240)],
      ),
    ),
    SkeletonPanel(child: SkeletonLines(lines: 3)),
    SkeletonPanel(child: Bone(height: 170)),
    SkeletonPanel(child: SkeletonTradeRows(count: 4)),
  ],
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _range = '30d';
  bool _cumulative = false;

  /// Isi yang terakhir tampil. Ganti periode berarti provider baru yang mulai
  /// dari kosong; selama memuat, isi lama tetap tampil supaya kerangka tidak
  /// mengganti daftar dan melempar posisi gulir ke atas.
  (int, Dashboard)? _shown;

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Dashboard',
    loading: _loading,
    actions: (_) => [
      IconButton(
        tooltip: 'Trade baru',
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => context.push('/trade/new'),
      ),
    ],
    body: (context, account) {
      final key = (account.id, _range);
      var value = ref.watch(dashboardProvider(key));
      final shown = _shown;

      if (value.hasValue) {
        _shown = (account.id, value.requireValue);
      } else if (value.isLoading && shown != null && shown.$1 == account.id) {
        value = AsyncData(shown.$2);
      }

      return RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider(key).future),
        child: AsyncView(
          value: value,
          onRetry: () => ref.invalidate(dashboardProvider(key)),
          loading: _loading,
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
        if (data.recent.isEmpty) ...[
          const _FirstSteps(),
          const SizedBox(height: 14),
        ],
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
              hint: 'Total setor ${money(summary.totalDeposited, currency)}',
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
              hint: '${summary.wins}W / ${summary.losses}L',
            ),
            // Pasangan winrate: seberapa besar menangnya dibanding kalahnya.
            StatCard(
              label: 'Rata-rata win',
              value: money(summary.avgWin, currency, signed: true),
              hint:
                  'Rata-rata loss ${money(-summary.avgLoss, currency, signed: true)}',
              tone: Tone.good,
            ),
            StatCard(
              label: 'Profit factor',
              value: summary.profitFactor == null
                  ? '—'
                  : number(summary.profitFactor),
              hint:
                  'Rata-rata ${money(summary.expectancy, currency, signed: true)} per trade',
              tone: (summary.profitFactor ?? 0) >= 1 ? Tone.good : Tone.bad,
            ),
            StatCard(
              label: 'Max drawdown',
              value: money(summary.maxDrawdown, currency),
              hint: pct(summary.maxDrawdownPct),
              tone: Tone.bad,
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
          title: 'P/L periode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pilihan yang sama dengan periode di atas: mengubah salah
              // satunya mengubah keduanya.
              Segments(
                value: _range,
                options: periods,
                onChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 14),
              PeriodPnlChart(data: data),
            ],
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

/// Pengguna baru melihat angka nol di mana-mana. Kartu ini menunjukkan
/// langkah pertamanya, dan hilang sendiri begitu trade pertama tercatat
/// (`recent` tidak dibatasi periode, jadi kosong berarti belum pernah ada).
class _FirstSteps extends StatelessWidget {
  const _FirstSteps();

  @override
  Widget build(BuildContext context) {
    Widget step(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.gold),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.mutedForeground,
      ),
      onTap: onTap,
    );

    return Panel(
      title: 'Mulai di sini',
      borderColor: AppColors.gold.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Caption('Tiga langkah supaya dashboard ini mulai berisi.'),
          const SizedBox(height: 4),
          step(
            Icons.account_balance_wallet_outlined,
            'Catat deposit pertama',
            'Saldo akun dimulai dari deposit ini.',
            () => context.go('/funds'),
          ),
          step(
            Icons.add_chart,
            'Catat trade pertama',
            'Isi manual, atau biarkan AI membaca screenshot.',
            () => context.push('/trade/new'),
          ),
          step(
            Icons.shield_outlined,
            'Atur batas harian',
            'Maksimal loss dan target profit per hari.',
            () => context.go('/more/rules'),
          ),
        ],
      ),
    );
  }
}
