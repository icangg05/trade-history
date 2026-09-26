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
          // Wrap, bukan Row: dengan huruf sistem besar ringkasannya turun ke
          // baris berikutnya alih-alih meluap keluar kartu.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Hari ini',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            // Tombol sungguhan, bukan tautan kecil di tengah kalimat: area
            // ketuknya cukup besar dan dikenali pembaca layar.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Caption(
                  'Belum ada aturan yang diisi. Tulis aturan trading kamu supaya '
                  'sisa jatah loss harian tampil di sini.',
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    iconAlignment: IconAlignment.end,
                  ),
                  onPressed: () => context.go('/more/rules'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Tulis aturan trading'),
                ),
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
                if (status.maxDrawdown != null)
                  Caption(
                    'Drawdown: ${money(status.drawdown, currency)} / ${money(status.maxDrawdown, currency)}',
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
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          Caption(label),
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
