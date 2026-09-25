import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/trade.dart';
import 'common.dart';

/// BUY emas, SELL abu — sama dengan badge di web.
class DirectionBadge extends StatelessWidget {
  const DirectionBadge(this.direction, {super.key, this.width = 44});

  final String direction;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final buy = direction == 'buy';

    // Lebar minimum, bukan lebar tetap: dengan huruf sistem yang besar
    // "SELL" melebar alih-alih pecah jadi dua baris.
    return Container(
      constraints: BoxConstraints(minWidth: width ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: buy ? AppColors.gold : AppColors.secondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        buy ? 'BUY' : 'SELL',
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
          color: buy ? AppColors.goldForeground : AppColors.foreground,
        ),
      ),
    );
  }
}

/// Stop yang sudah digeser: BE (persis di entry) atau SL+ (sudah lewat entry).
/// Selalu memberi alasan kenapa kolom R kosong.
class StopBadge extends StatelessWidget {
  const StopBadge(this.state, {super.key});

  final StopState? state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      StopState.breakeven => 'BE',
      StopState.locked => 'SL+',
      _ => null,
    };

    if (label == null) return const SizedBox.shrink();

    return Tooltip(
      message: state == StopState.breakeven
          ? 'Stop loss di harga entry — risiko nol, R tidak dihitung'
          : 'Stop loss sudah lewat entry — profit terkunci, R tidak dihitung',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          softWrap: false,
          style: const TextStyle(fontSize: 11, color: AppColors.cyan),
        ),
      ),
    );
  }
}

Color statusColor(String status) => switch (status) {
  'win' => AppColors.success,
  'loss' => AppColors.destructive,
  _ => AppColors.mutedForeground,
};

String statusLabel(String status) => switch (status) {
  'win' => 'Win',
  'loss' => 'Loss',
  _ => 'BE',
};

/// Satu baris trade ringkas: arah, simbol, keterangan kecil, P/L.
/// Dipakai dashboard, riwayat trade, dan kalender.
class TradeRow extends StatelessWidget {
  const TradeRow({
    super.key,
    required this.trade,
    required this.currency,
    required this.subtitle,
    this.onTap,
    this.leading,
    this.trailingBelow,
    this.dimmed = false,
    this.highlighted = false,
  });

  final Trade trade;
  final String currency;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? leading;
  final String? trailingBelow;
  final bool dimmed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    // Huruf sistem besar: nominal pindah ke bawah simbol, jadi simbolnya
    // tidak terjepit jadi "XAU…".
    final stacked = largeText(context);
    final amounts = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          money(trade.pnl, currency, signed: true),
          style: mono(size: 12.5, color: statusColor(trade.status)),
        ),
        if (trailingBelow != null)
          Text(
            trailingBelow!,
            style: mono(size: 11, color: AppColors.mutedForeground),
          ),
      ],
    );

    return Opacity(
      opacity: dimmed ? .4 : 1,
      child: Material(
        color: highlighted
            ? AppColors.gold.withValues(alpha: .1)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                DirectionBadge(trade.direction),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trade.symbol,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (trade.source == 'ai') ...[
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'Diisi dari screenshot',
                              child: Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          if (trade.stopState != null &&
                              trade.stopState != StopState.risk) ...[
                            const SizedBox(width: 4),
                            StopBadge(trade.stopState),
                          ],
                        ],
                      ),
                      if (stacked) ...[const SizedBox(height: 4), amounts],
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 8), amounts],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bingkai grup: trade yang satu grup dibungkus satu garis emas tipis —
/// satu-satunya penanda grup, tanpa nama atau label. Padanan `useGroupFrame.ts`.
///
/// `rows` harus urut waktu; anggota satu grup selalu bersebelahan di sana.
BoxDecoration? groupFrame(List<Trade> rows, int index) {
  final group = rows[index].groupId;

  if (group == null) return null;

  final side = BorderSide(color: AppColors.gold.withValues(alpha: .4));
  final first = index == 0 || rows[index - 1].groupId != group;
  final last = index == rows.length - 1 || rows[index + 1].groupId != group;

  return BoxDecoration(
    color: AppColors.gold.withValues(alpha: .04),
    border: Border(
      left: side,
      right: side,
      top: first ? side : BorderSide.none,
      bottom: last ? side : BorderSide.none,
    ),
  );
}

/// Dua grup yang bersebelahan butuh jeda, supaya tutup bawah yang satu dan
/// tutup atas yang lain tidak terbaca sebagai satu bingkai panjang.
bool groupGap(List<Trade> rows, int index) {
  final group = rows[index].groupId;
  final previous = index == 0 ? null : rows[index - 1].groupId;

  return group != null && previous != null && group != previous;
}

/// Garis pemisah di bawah baris `index`. Di tepi grup garisnya sudah digambar
/// bingkai emas, jadi pemisah biasa hanya di luar grup atau di dalam grup yang sama.
bool rowDivider(List<Trade> rows, int index) {
  if (index >= rows.length - 1) return false;

  final group = rows[index].groupId;
  final next = rows[index + 1].groupId;

  return group == next;
}
