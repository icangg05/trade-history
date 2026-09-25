import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/journal.dart';
import '../../models/stats.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/markdown_view.dart';
import '../dashboard/dashboard_screen.dart' show periods;

final analysisProvider = FutureProvider.autoDispose
    .family<AnalysisPage, (int, String)>((ref, key) {
      ref.watch(revisionProvider);

      return ref.watch(journalProvider).analysis(key.$1, key.$2);
    });

/// Statistik dihitung dari database; AI hanya menafsirkan angkanya.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  String _period = '30d';
  bool _generating = false;

  Future<void> _generate(int account) async {
    setState(() => _generating = true);

    try {
      final message = await ref
          .read(journalProvider)
          .generateAnalysis(account, _period);

      ref.read(revisionProvider.notifier).bump();
      if (mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Analisa',
    actions: (_) => [
      TextButton.icon(
        onPressed: () => context.push('/chat?period=$_period'),
        icon: const Icon(Icons.forum_outlined, size: 18),
        label: const Text('Tanya AI'),
      ),
    ],
    body: (context, account) {
      final key = (account.id, _period);

      return RefreshIndicator(
        onRefresh: () => ref.refresh(analysisProvider(key).future),
        child: AsyncView(
          value: ref.watch(analysisProvider(key)),
          onRetry: () => ref.invalidate(analysisProvider(key)),
          builder: (page) => _content(page, account.id),
        ),
      );
    },
  );

  Widget _content(AnalysisPage page, int account) {
    final summary = page.summary;
    final currency = summary.currency;

    return ListView(
      scrollCacheExtent: kWholePageCache,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const Caption(
          'Statistik dihitung dari database; AI hanya menafsirkan angkanya.',
        ),
        const SizedBox(height: 10),
        Segments(
          value: _period,
          options: periods,
          onChanged: (value) => setState(() => _period = value),
        ),
        const SizedBox(height: 14),
        StatGrid(
          children: [
            StatCard(
              label: 'Trade',
              value: '${summary.totalTrades}',
              hint: '${summary.wins} win, ${summary.losses} loss',
            ),
            StatCard(
              label: 'Net P/L',
              value: money(summary.netPnl, currency, signed: true),
              tone: summary.netPnl >= 0 ? Tone.good : Tone.bad,
            ),
            StatCard(
              label: 'Winrate',
              value: pct(summary.winRate),
              hint: '${summary.wins}W / ${summary.losses}L',
            ),
            StatCard(
              label: 'Payoff',
              value: summary.payoffRatio == null
                  ? '—'
                  : number(summary.payoffRatio),
              hint:
                  'Menang ${money(summary.avgWin, currency)} · kalah ${money(summary.avgLoss, currency)}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Breakdown(
          title: 'Per simbol',
          rows: summary.bySymbol,
          currency: currency,
          limit: 5,
        ),
        const SizedBox(height: 14),
        _Breakdown(
          title: 'Per hari',
          rows: summary.byWeekday,
          currency: currency,
          limit: 7,
        ),
        const SizedBox(height: 14),
        _Breakdown(
          title: 'Per setup',
          rows: summary.bySetup,
          currency: currency,
          limit: 6,
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Angka lain',
          child: Column(
            children: [
              _figure(
                'Profit factor',
                summary.profitFactor == null
                    ? '—'
                    : number(summary.profitFactor),
              ),
              _figure(
                'Ekspektasi / trade',
                money(summary.expectancy, currency, signed: true),
              ),
              _figure(
                'Max drawdown',
                '${money(summary.maxDrawdown, currency)} (${pct(summary.maxDrawdownPct)})',
              ),
              _figure('Menang beruntun', '${summary.longestWinStreak}'),
              _figure('Kalah beruntun', '${summary.longestLossStreak}'),
              _figure('RR rata-rata', rr(summary.avgRrRealized)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _aiCard(page, account),
      ],
    );
  }

  Widget _figure(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Caption(label)),
        Text(value, style: mono(size: 12.5)),
      ],
    ),
  );

  Widget _aiCard(AnalysisPage page, int account) {
    final analysis = page.analysis;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analisa AI',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Caption(
                      'Model ${page.model}. Hasil terakhir tetap tersimpan walau data berubah.',
                    ),
                    if (analysis != null)
                      Caption(
                        'Terakhir dianalisa ${dateTime(analysis.analyzedAt)}'
                        '${analysis.stale ? ' · data sudah berubah sejak itu' : ''}',
                        color: analysis.stale ? AppColors.gold : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BusyButton(
                busy: _generating,
                icon: Icons.auto_awesome,
                label: analysis == null ? 'Analisa' : 'Perbarui',
                onPressed: page.aiEnabled ? () => _generate(account) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!page.aiEnabled)
            const EmptyState(
              icon: Icons.key_off_outlined,
              message: 'Kunci Gemini belum diisi. Minta admin mengisinya di halaman Admin.',
            )
          else if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Shimmer(child: Panel(child: SkeletonLines(lines: 7))),
                  SizedBox(height: 14),
                  Text('Sedang membaca jurnalmu…'),
                  SizedBox(height: 4),
                  Caption(
                    'Analisa penuh biasanya butuh 20-60 detik. Layar tidak perlu ditutup.',
                  ),
                ],
              ),
            )
          else if (analysis != null) ...[
            MarkdownView(analysis.markdown),
            const Divider(height: 24),
            Caption(
              'Ditulis ${analysis.model} atas data ${longDate(analysis.periodStart)} sampai '
              '${longDate(analysis.periodEnd)}. Ini bukan saran finansial, hanya pembacaan pola dari jurnalmu sendiri.',
            ),
          ] else
            const EmptyState(
              icon: Icons.auto_awesome_outlined,
              message: 'Belum ada analisa untuk periode ini.',
            ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.rows,
    required this.currency,
    required this.limit,
  });

  final String title;
  final Map<String, BreakdownRow> rows;
  final String currency;
  final int limit;

  @override
  Widget build(BuildContext context) => Panel(
    title: title,
    child: rows.isEmpty
        ? const Caption('Belum ada data.')
        : Column(
            children: [
              for (final MapEntry(:key, :value) in rows.entries.take(limit))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: key,
                            children: [
                              TextSpan(
                                text:
                                    '  (${value.trades} · ${pct(value.winRate, 0)})',
                                style: const TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        money(value.pnl, currency, signed: true),
                        style: mono(size: 12.5, color: pnlColor(value.pnl)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}
