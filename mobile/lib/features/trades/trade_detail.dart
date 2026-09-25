import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/trade.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/setup_picker.dart';
import '../../widgets/trade_widgets.dart';

/// Detail satu trade. Baris di daftar diringkas jadi simbol, waktu, dan P/L;
/// sisanya menunggu di sini, bukan menumpuk di daftar.
///
/// `rows` adalah daftar tempat trade itu tampil (urut waktu). Hanya dengan
/// daftar itu grup bisa dikelola — dari dashboard dan kalender, grupnya cukup
/// ditunjukkan.
Future<void> showTradeDetail(
  BuildContext context, {
  required int account,
  required String currency,
  required Trade trade,
  List<Trade>? rows,
}) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .7,
    maxChildSize: .95,
    builder: (context, scroll) => TradeDetailSheet(
      account: account,
      currency: currency,
      initial: trade,
      rows: rows,
      scroll: scroll,
    ),
  ),
);

final _tradeProvider = FutureProvider.autoDispose.family<Trade?, (int, String)>(
  (ref, key) async =>
      (await ref.watch(journalProvider).tradeForm(key.$1, key.$2)).$1,
);

class TradeDetailSheet extends ConsumerStatefulWidget {
  const TradeDetailSheet({
    super.key,
    required this.account,
    required this.currency,
    required this.initial,
    required this.scroll,
    this.rows,
  });

  final int account;
  final String currency;
  final Trade initial;
  final List<Trade>? rows;
  final ScrollController scroll;

  @override
  ConsumerState<TradeDetailSheet> createState() => _TradeDetailSheetState();
}

class _TradeDetailSheetState extends ConsumerState<TradeDetailSheet> {
  late String _setup = widget.initial.setup ?? '';
  late final _notes = TextEditingController(text: widget.initial.notes ?? '');
  bool _busy = false;

  /// Dashboard dan kalender hanya mengirim ringkasan; harga-harganya diambil dulu.
  bool get _complete => widget.initial.entryPrice != null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);

    try {
      final message = await action();

      ref.read(revisionProvider.notifier).bump();

      if (mounted) {
        showMessage(context, message);
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Trade trade) async {
    if (!await confirm(
      context,
      title: 'Hapus trade ${trade.symbol}?',
      action: 'Hapus',
    )) {
      return;
    }

    await _run(
      () => ref.read(journalProvider).deleteTrade(widget.account, trade.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return _content(widget.initial);

    return ref
        .watch(_tradeProvider((widget.account, widget.initial.id)))
        .when(
          data: (trade) => trade == null
              ? const EmptyState(message: 'Trade tidak ditemukan.')
              : _content(trade),
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Shimmer(child: SkeletonLines(lines: 8)),
          ),
          error: (error, _) => ErrorView(error: error),
        );
  }

  /// Label kecil di atas angka mono — satu sel detail.
  Widget _fact(
    String label,
    String value, {
    double size = 13,
    Color? color,
    bool end = false,
  }) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Caption(label),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono(
          size: size,
          weight: size > 13 ? FontWeight.w600 : FontWeight.w400,
          color: color,
        ),
      ),
    ],
  );

  Widget _content(Trade trade) {
    final rows = widget.rows;
    final members = rows == null || trade.groupId == null
        ? const <Trade>[]
        : rows.where((row) => row.groupId == trade.groupId).toList();
    final atEdge =
        members.isNotEmpty &&
        (members.first.id == trade.id || members.last.id == trade.id);

    // Berpasangan kiri-kanan: harga masuk-keluar, batas rugi-untung, ukuran
    // dan rencana, lalu waktunya.
    final details = [
      (('Entry', price(trade.entryPrice)), ('Exit', price(trade.exitPrice))),
      (
        ('Stop loss', price(trade.slPrice)),
        ('Take profit', price(trade.tpPrice)),
      ),
      (('Lot', number(trade.lot)), ('RR rencana', rr(trade.rrPlanned))),
      (
        ('Dibuka', shortDateTime(trade.openedAt)),
        ('Ditutup', shortDateTime(trade.closedAt)),
      ),
    ];
    final tone = pnlColor(trade.pnl);

    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                trade.symbol,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DirectionBadge(trade.direction),
            if (trade.source == 'ai') ...[
              const SizedBox(width: 6),
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              statusLabel(trade.status),
              style: TextStyle(fontSize: 12, color: statusColor(trade.status)),
            ),
            const SizedBox(width: 6),
            StopBadge(trade.stopState),
          ],
        ),
        const SizedBox(height: 14),
        // Yang paling dicari lebih dulu: hasilnya.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(kRadius - 2),
            border: Border.all(color: tone.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _fact(
                  'P/L',
                  money(trade.pnl, widget.currency, signed: true),
                  size: 18,
                  color: tone,
                ),
              ),
              _fact('RR hasil', rr(trade.rrRealized), size: 18, end: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Baris setinggi isinya — bukan sel ber-rasio tetap yang
        // meninggalkan ruang kosong di bawah setiap angka.
        for (final (left, right) in details) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _fact(left.$1, left.$2)),
              const SizedBox(width: 12),
              Expanded(child: _fact(right.$1, right.$2)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        if (trade.groupId != null && rows != null)
          Notice(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Satu grup dengan ${members.length - 1} trade lain',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (atEdge)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => ref
                                    .read(journalProvider)
                                    .ungroup(widget.account, trade.id),
                              ),
                        child: const Text('Keluarkan'),
                      )
                    else
                      const Caption('Keluarkan dari ujung dulu'),
                  ],
                ),
                const SizedBox(height: 8),
                const Caption('Setup / strategi grup'),
                const SizedBox(height: 6),
                SetupPicker(
                  value: _setup,
                  onChanged: (value) => setState(() => _setup = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Catatan grup',
                    hintText:
                        'Contoh: Tiga entry di zona demand yang sama, dua pertama terlalu cepat.',
                    hintMaxLines: 3,
                    helperText:
                        'Kenapa masuk berkali-kali, kondisi pasar, dan pelajarannya.',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: BusyButton(
                    busy: _busy,
                    label: 'Simpan grup',
                    onPressed: () => _run(
                      () => ref
                          .read(journalProvider)
                          .updateGroup(
                            widget.account,
                            trade.groupId!,
                            setup: _setup,
                            notes: _notes.text,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (trade.groupId != null) ...[
            const Notice(
              icon: Icons.layers_outlined,
              child: Text(
                'Trade ini bagian dari sebuah grup. Kelola grupnya dari tab Trade.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if ((trade.setup ?? '').isNotEmpty) ...[
            const Caption('Setup'),
            const SizedBox(height: 2),
            Text(trade.setup!, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 12),
          ],
          if ((trade.notes ?? '').isNotEmpty) ...[
            const Caption('Catatan'),
            const SizedBox(height: 2),
            Text(
              trade.notes!,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
        const Divider(height: 24),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _delete(trade),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Hapus'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                final router = GoRouter.of(context);

                Navigator.pop(context);
                router.push('/trade/${trade.id}');
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Ubah'),
            ),
          ],
        ),
      ],
    );
  }
}
