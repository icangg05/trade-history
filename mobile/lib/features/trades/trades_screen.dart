import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/trade.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/trade_widgets.dart';
import 'trade_detail.dart';
import 'trade_filters_sheet.dart';

/// Riwayat yang sudah dimuat, halaman demi halaman.
class TradeList {
  const TradeList({
    required this.items,
    required this.daily,
    required this.symbols,
    required this.setups,
    required this.total,
    required this.page,
    required this.lastPage,
    this.loadingMore = false,
  });

  factory TradeList.first(TradePage page) => TradeList(
    items: page.items,
    daily: page.daily,
    symbols: page.symbols,
    setups: page.setups,
    total: page.total,
    page: page.page,
    lastPage: page.lastPage,
  );

  final List<Trade> items;
  final Map<String, double> daily;
  final List<String> symbols;
  final List<String> setups;
  final int total;
  final int page;
  final int lastPage;
  final bool loadingMore;

  bool get hasMore => page < lastPage;

  TradeList append(TradePage next) => TradeList(
    items: [...items, ...next.items],
    daily: {...daily, ...next.daily},
    symbols: symbols,
    setups: setups,
    total: next.total,
    page: next.page,
    lastPage: next.lastPage,
  );

  TradeList loading(bool value) => TradeList(
    items: items,
    daily: daily,
    symbols: symbols,
    setups: setups,
    total: total,
    page: page,
    lastPage: lastPage,
    loadingMore: value,
  );
}

typedef TradeQuery = (int account, TradeFilters filters);

class TradesController extends AsyncNotifier<TradeList> {
  TradesController(this.query);

  final TradeQuery query;

  @override
  Future<TradeList> build() async {
    ref.watch(revisionProvider);

    return TradeList.first(
      await ref.watch(journalProvider).trades(query.$1, query.$2, 1),
    );
  }

  /// Halaman berikutnya ditempel di bawah — gulir tanpa tombol halaman.
  Future<void> loadMore() async {
    final current = state.value;

    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.loading(true));

    try {
      final next = await ref
          .read(journalProvider)
          .trades(query.$1, query.$2, current.page + 1);

      if (ref.mounted) state = AsyncData(current.append(next));
    } on ApiException {
      if (ref.mounted) state = AsyncData(current.loading(false));
    }
  }
}

final tradesProvider = AsyncNotifierProvider.autoDispose
    .family<TradesController, TradeList, TradeQuery>(TradesController.new);

class TradesScreen extends ConsumerStatefulWidget {
  const TradesScreen({super.key});

  @override
  ConsumerState<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends ConsumerState<TradesScreen> {
  TradeFilters _filters = noTradeFilters;
  final _scroll = ScrollController();

  /// Mode pilih: menandai beberapa trade berurutan sebagai satu ide.
  bool _grouping = false;
  List<String> _picked = [];
  bool _saving = false;

  TradeQuery? _query;

  @override
  void initState() {
    super.initState();

    _scroll.addListener(() {
      if (_query != null && _scroll.position.extentAfter < 600) {
        ref.read(tradesProvider(_query!).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _stopGrouping() => setState(() {
    _grouping = false;
    _picked = [];
  });

  Future<void> _saveGroup(int account) async {
    setState(() => _saving = true);

    try {
      final message = await ref.read(journalProvider).group(account, _picked);

      ref.read(revisionProvider.notifier).bump();
      if (mounted) showMessage(context, message);
      _stopGrouping();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Riwayat trade',
    actions: (account) => [
      IconButton(
        tooltip: _grouping ? 'Batal grouping' : 'Grouping',
        icon: Icon(
          _grouping ? Icons.close : Icons.layers_outlined,
          color: _grouping ? AppColors.gold : null,
        ),
        onPressed: () =>
            _grouping ? _stopGrouping() : setState(() => _grouping = true),
      ),
      IconButton(
        tooltip: 'Filter',
        icon: Badge(
          isLabelVisible: _filters.active > 0,
          label: Text('${_filters.active}'),
          backgroundColor: AppColors.gold,
          textColor: AppColors.goldForeground,
          child: const Icon(Icons.tune),
        ),
        onPressed: () async {
          final list = ref.read(tradesProvider((account.id, _filters))).value;
          final next = await showTradeFilters(
            context,
            filters: _filters,
            symbols: list?.symbols ?? const [],
            setups: list?.setups ?? const [],
          );

          if (next != null) setState(() => _filters = next);
        },
      ),
    ],
    floatingActionButton: (_) => _grouping
        ? null
        : FloatingActionButton.extended(
            onPressed: () => context.push('/trade/new'),
            icon: const Icon(Icons.add),
            label: const Text('Trade'),
          ),
    body: (context, account) {
      final query = (account.id, _filters);
      _query = query;

      return RefreshIndicator(
        onRefresh: () => ref.refresh(tradesProvider(query).future),
        child: AsyncView(
          value: ref.watch(tradesProvider(query)),
          onRetry: () => ref.invalidate(tradesProvider(query)),
          builder: (list) => _list(list, account),
        ),
      );
    },
  );

  Widget _list(TradeList list, AccountBrief account) {
    final rows = list.items;
    final entries = <Widget>[];

    for (var i = 0; i < rows.length; i++) {
      final trade = rows[i];

      // Pembatas tanggal tiap ganti hari. Harinya dihitung dari waktu tutup,
      // dan P/L-nya datang dari server supaya utuh walau terpotong halaman.
      if (i == 0 || rows[i - 1].dayKey != trade.dayKey) {
        entries.add(
          _DayHeader(
            day: trade.day,
            pnl: list.daily[trade.dayKey],
            currency: account.currency,
          ),
        );
      } else if (groupGap(rows, i)) {
        entries.add(const SizedBox(height: 6));
      }

      final picked = _picked.contains(trade.id);
      final pickable = _pickable(rows, trade);

      entries.add(
        DecoratedBox(
          decoration: groupFrame(rows, i) ?? const BoxDecoration(),
          child: TradeRow(
            trade: trade,
            currency: account.currency,
            subtitle: [
              clock(trade.openedAt),
              if ((trade.setup ?? '').isNotEmpty) trade.setup!,
            ].join(' · '),
            highlighted: _grouping && picked,
            dimmed: _grouping && !pickable,
            leading: _grouping
                ? Icon(
                    picked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 20,
                    color: picked ? AppColors.gold : AppColors.mutedForeground,
                  )
                : null,
            onTap: _grouping
                ? () => _toggle(rows, trade)
                : () => showTradeDetail(
                    context,
                    account: account.id,
                    currency: account.currency,
                    trade: trade,
                    rows: rows,
                  ),
          ),
        ),
      );

      if (rowDivider(rows, i) && rows[i + 1].dayKey == trade.dayKey) {
        entries.add(const Divider(indent: 12, endIndent: 12));
      }
    }

    return Column(
      children: [
        if (_grouping)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Notice(
              icon: Icons.layers_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pilih trade yang berurutan — hanya baris tepat di atas atau di bawah pilihan yang bisa ikut. '
                    'Ikutkan anggota grup yang sudah ada untuk menambah trade ke dalamnya.',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: BusyButton(
                      busy: _saving,
                      label: 'Grouping ${_picked.length} trade',
                      onPressed: _picked.length < 2
                          ? null
                          : () => _saveGroup(account.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Caption(
                  '${list.total} trade tercatat'
                  '${_filters.active > 0 ? ' · ${_filters.active} filter aktif' : ''}',
                ),
              ),
              if (rows.isEmpty)
                EmptyState(
                  message: _filters.active > 0
                      ? 'Tidak ada trade yang cocok.'
                      : 'Belum ada trade.',
                  action: _filters.active > 0
                      ? TextButton(
                          onPressed: () =>
                              setState(() => _filters = noTradeFilters),
                          child: const Text('Bersihkan filter'),
                        )
                      : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: entries),
                  ),
                ),
              if (list.loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (rows.isNotEmpty && !list.hasMore)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Caption(
                    'Tanda BE berarti stop loss sudah dipindah ke harga entry, sedangkan SL+ berarti sudah '
                    'melewatinya. Risikonya sudah dilepas, jadi nilai R tidak lagi bisa dihitung.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- mode pilih

  Set<String> _pickedGroups(List<Trade> rows) => {
    for (final id in _picked)
      if (rows.where((row) => row.id == id).firstOrNull?.groupId
          case final String group)
        group,
  };

  /// Sebuah grup dipilih sebagai satu kesatuan: rentangnya dari anggota pertama
  /// sampai terakhir. Rentang inilah yang dipakai menilai kebersebelahan.
  (int, int) _block(List<Trade> rows, Trade trade) {
    if (trade.groupId == null) {
      final at = rows.indexWhere((row) => row.id == trade.id);

      return (at, at);
    }

    final indexes = [
      for (var i = 0; i < rows.length; i++)
        if (rows[i].groupId == trade.groupId) i,
    ];

    return (indexes.first, indexes.last);
  }

  bool _pickable(List<Trade> rows, Trade trade) {
    if (!_grouping) return false;

    final groups = _pickedGroups(rows);

    // Menambah anggota ke grup yang sudah ada boleh; menyentuh grup kedua tidak.
    if (trade.groupId != null &&
        groups.isNotEmpty &&
        !groups.contains(trade.groupId)) {
      return false;
    }

    if (_picked.isEmpty) return true;

    final indexes = [
      for (final id in _picked) rows.indexWhere((row) => row.id == id),
    ];
    final first = indexes.reduce((a, b) => a < b ? a : b);
    final last = indexes.reduce((a, b) => a > b ? a : b);
    final (blockFirst, blockLast) = _block(rows, trade);

    // Boleh dicentang kalau menempel di ujung pilihan, dan boleh dilepas kalau
    // dia sendiri yang ada di ujung — supaya pilihannya tidak pernah berlubang.
    return blockLast == first - 1 ||
        blockFirst == last + 1 ||
        blockFirst == first ||
        blockLast == last;
  }

  void _toggle(List<Trade> rows, Trade trade) {
    if (!_pickable(rows, trade)) return;

    // Anggota satu grup selalu ikut bersama-sama.
    final ids = trade.groupId == null
        ? [trade.id]
        : [
            for (final row in rows)
              if (row.groupId == trade.groupId) row.id,
          ];

    setState(() {
      _picked = ids.every(_picked.contains)
          ? _picked.where((id) => !ids.contains(id)).toList()
          : {..._picked, ...ids}.toList();
    });
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.pnl,
    required this.currency,
  });

  final DateTime day;
  final double? pnl;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.muted.withValues(alpha: .5),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            longDate(day).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: .6,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        if (pnl != null)
          Text(
            money(pnl, currency, signed: true),
            style: mono(size: 11, color: pnlColor(pnl)),
          ),
      ],
    ),
  );
}
