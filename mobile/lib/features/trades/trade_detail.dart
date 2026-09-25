import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/trade.dart';
import '../../widgets/common.dart';
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
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorView(error: error),
        );
  }

  Widget _content(Trade trade) {
    final rows = widget.rows;
    final members = rows == null || trade.groupId == null
        ? const <Trade>[]
        : rows.where((row) => row.groupId == trade.groupId).toList();
    final atEdge =
        members.isNotEmpty &&
        (members.first.id == trade.id || members.last.id == trade.id);

    final details = [
      ('Lot', number(trade.lot)),
      ('Entry', price(trade.entryPrice)),
      ('Stop loss', price(trade.slPrice)),
      ('Take profit', price(trade.tpPrice)),
      ('Exit', price(trade.exitPrice)),
      ('P/L', money(trade.pnl, widget.currency, signed: true)),
      ('RR rencana', rr(trade.rrPlanned)),
      ('RR hasil', rr(trade.rrRealized)),
    ];

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
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                '${statusLabel(trade.status)} · ${dateTime(trade.openedAt)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor(trade.status),
                ),
              ),
            ),
            const SizedBox(width: 6),
            StopBadge(trade.stopState),
          ],
        ),
        const Divider(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 12,
          children: [
            for (final (label, value) in details)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Caption(label),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(size: 12.5),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Caption('Ditutup'),
        Text(dateTime(trade.closedAt), style: mono(size: 12.5)),
        const SizedBox(height: 12),
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
                  dense: true,
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
                    hintText: 'Alasan entry, kondisi pasar, evaluasi…',
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
        const Divider(height: 28),
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
