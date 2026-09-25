import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/stats.dart';
import 'common.dart';

/// "Hari ini": sisa jatah loss, target profit, jumlah trade, drawdown, RR
/// minimum. Murni pengingat — tidak ada yang diblokir. Padanan `RuleStatusBanner.vue`.
class RuleStatusCard extends StatelessWidget {
  const RuleStatusCard({
    super.key,
    required this.status,
    required this.currency,
  });

  final RuleStatus status;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final lossLimit = status.lossLimit;
    final profitGoal = status.profitGoal;
    final lossPct = lossLimit == null || lossLimit == 0
        ? 0.0
        : (status.lossUsed / lossLimit).clamp(0.0, 1.0);
    final profitPct = profitGoal == null || profitGoal == 0 || status.pnl <= 0
        ? 0.0
        : (status.pnl / profitGoal).clamp(0.0, 1.0);

    return Panel(
      borderColor: status.breached
          ? AppColors.destructive.withValues(alpha: .5)
          : (status.profitReached
                ? AppColors.success.withValues(alpha: .4)
                : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hari ini',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${money(status.pnl, currency, signed: true)} · ${status.trades} trade',
                style: mono(
                  size: 12.5,
                  color: status.pnl >= 0
                      ? AppColors.success
                      : AppColors.destructive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!status.hasRules)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Caption('Belum ada aturan yang diisi. '),
                GestureDetector(
                  onTap: () => context.go('/more/rules'),
                  child: const Text(
                    'Tulis aturan trading kamu',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.gold,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.gold,
                    ),
                  ),
                ),
                const Caption(' supaya sisa jatah loss harian tampil di sini.'),
              ],
            )
          else ...[
            if (lossLimit != null) ...[
              _Meter(
                label: 'Batas loss harian',
                value:
                    '${money(status.lossUsed, currency)} / ${money(lossLimit, currency)}',
                fraction: lossPct,
                color: status.lossBreached
                    ? AppColors.destructive
                    : (lossPct > .6
                          ? AppColors.gold
                          : AppColors.mutedForeground),
              ),
              const SizedBox(height: 4),
              Caption(
                status.lossBreached
                    ? 'Batas loss hari ini sudah terlampaui — waktunya berhenti.'
                    : 'Sisa ${money(lossLimit - status.lossUsed, currency)}.',
                color: status.lossBreached ? AppColors.destructive : null,
              ),
              const SizedBox(height: 12),
            ],
            if (profitGoal != null) ...[
              _Meter(
                label: 'Target profit harian',
                value:
                    '${money(status.pnl, currency)} / ${money(profitGoal, currency)}',
                fraction: profitPct,
                color: AppColors.success,
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (status.maxTrades != null)
                  Caption(
                    'Trade: ${status.trades} / ${status.maxTrades}',
                    color: status.tradesBreached ? AppColors.destructive : null,
                  ),
                if (status.maxDrawdownPct != null)
                  Caption(
                    'Drawdown: ${pct(status.drawdownPct)} / ${pct(status.maxDrawdownPct)}',
                    color: status.drawdownBreached
                        ? AppColors.destructive
                        : null,
                  ),
                if (status.minRr != null)
                  Caption(
                    'RR minimum ${number(status.minRr)}'
                    '${status.lowRrTrades > 0 ? ' — ${status.lowRrTrades} trade di bawahnya' : ''}',
                    color: status.lowRrTrades > 0
                        ? AppColors.destructive
                        : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Caption(label)),
          Text(value, style: mono(size: 11.5)),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: fraction,
          minHeight: 6,
          color: color,
          backgroundColor: AppColors.muted,
        ),
      ),
    ],
  );
}
