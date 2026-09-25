import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/journal.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import 'transaction_form.dart';

/// Filter periode: tahun + bulan, atau `all`. Bulan hanya berarti kalau
/// tahunnya juga dipilih — "Agustus" lintas tahun bukan angka yang berarti.
typedef FundsQuery = (int account, String year, String month);

class FundsList {
  const FundsList({
    required this.first,
    required this.items,
    required this.page,
    this.loadingMore = false,
  });

  final TransactionsPage first;
  final List<FundTransaction> items;
  final int page;
  final bool loadingMore;

  bool get hasMore => page < first.lastPage;
}

class FundsController extends AsyncNotifier<FundsList> {
  FundsController(this.query);

  final FundsQuery query;

  @override
  Future<FundsList> build() async {
    ref.watch(revisionProvider);

    final first = await ref
        .watch(journalProvider)
        .transactions(query.$1, year: query.$2, month: query.$3);

    return FundsList(first: first, items: first.items, page: first.page);
  }

  Future<void> loadMore() async {
    final current = state.value;

    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(
      FundsList(
        first: current.first,
        items: current.items,
        page: current.page,
        loadingMore: true,
      ),
    );

    try {
      final next = await ref
          .read(journalProvider)
          .transactions(
            query.$1,
            year: query.$2,
            month: query.$3,
            page: current.page + 1,
          );

      if (ref.mounted) {
        state = AsyncData(
          FundsList(
            first: current.first,
            items: [...current.items, ...next.items],
            page: next.page,
          ),
        );
      }
    } on ApiException {
      if (ref.mounted) state = AsyncData(current);
    }
  }
}

final fundsProvider = AsyncNotifierProvider.autoDispose
    .family<FundsController, FundsList, FundsQuery>(FundsController.new);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // Bawaannya periode berjalan — yang dilihat orang sembilan dari sepuluh kali.
  String _year = '${DateTime.now().year}';
  String _month = '${DateTime.now().month}';

  Future<void> _delete(AccountBrief account, FundTransaction row) async {
    final ok = await confirmWithCode(
      context,
      title: row.isDeposit ? 'Hapus deposit ini?' : 'Hapus withdrawal ini?',
      description:
          '${money(row.amount, account.currency)} pada ${longDate(row.occurredAt)} beserta bukti transfernya '
          'dihapus permanen, dan saldo akun ikut berubah.',
      confirmLabel: 'Hapus transaksi',
    );

    if (!ok) return;

    try {
      final message = await ref
          .read(journalProvider)
          .deleteTransaction(account.id, row.id);

      ref.read(revisionProvider.notifier).bump();
      if (mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  FundsQuery _query(AccountBrief account) =>
      (account.id, _year, _year == 'all' ? 'all' : _month);

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Dana',
    floatingActionButton: (account) => FloatingActionButton.extended(
      onPressed: () => showTransactionForm(
        context,
        account: account,
        balance: ref
            .read(fundsProvider(_query(account)))
            .value
            ?.first
            .totals
            .balance,
      ),
      icon: const Icon(Icons.add),
      label: const Text('Catat'),
    ),
    body: (context, account) {
      final query = _query(account);

      return RefreshIndicator(
        onRefresh: () => ref.refresh(fundsProvider(query).future),
        child: AsyncView(
          value: ref.watch(fundsProvider(query)),
          onRetry: () => ref.invalidate(fundsProvider(query)),
          builder: (list) => NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) {
                ref.read(fundsProvider(query).notifier).loadMore();
              }
              return false;
            },
            child: _content(list, account),
          ),
        ),
      );
    },
  );

  Widget _content(FundsList list, AccountBrief account) {
    final page = list.first;
    final totals = page.totals;
    final currency = account.currency;
    final needsRate = currency != 'IDR';
    final scope = page.year == null
        ? 'sepanjang waktu'
        : (page.month == null
              ? '${page.year}'
              : monthLabel('${page.year}-${'${page.month}'.padLeft(2, '0')}'));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        const Caption('Arus dana masuk-keluar, terpisah dari hasil trading.'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Tahun'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Semua tahun'),
                  ),
                  for (final year in page.years)
                    DropdownMenuItem(value: '$year', child: Text('$year')),
                ],
                onChanged: (value) => setState(() => _year = value ?? 'all'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                // Isian form hanya membaca nilai awal; kuncinya berganti supaya
                // bulan ikut terkunci ke "semua" saat tahunnya "semua".
                key: ValueKey('month-$_year'),
                initialValue: _year == 'all' ? 'all' : _month,
                decoration: const InputDecoration(labelText: 'Bulan'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Semua bulan'),
                  ),
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem(
                      value: '$month',
                      child: Text(
                        monthLabel('2000-${'$month'.padLeft(2, '0')}')
                            .split(' ')
                            .first,
                      ),
                    ),
                ],
                onChanged: _year == 'all'
                    ? null
                    : (value) => setState(() => _month = value ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StatGrid(
          children: [
            StatCard(
              label: 'Saldo sekarang',
              value: money(totals.balance, currency),
              tone: Tone.gold,
            ),
            StatCard(
              label: 'Modal awal',
              value: money(totals.initialBalance, currency),
            ),
            StatCard(
              label: 'Deposit · $scope',
              value: money(totals.deposit, currency),
              hint: needsRate ? money(totals.depositIdr, 'IDR') : null,
              tone: Tone.good,
            ),
            StatCard(
              label: 'Withdrawal · $scope',
              value: money(totals.withdrawal, currency),
              hint: needsRate ? money(totals.withdrawalIdr, 'IDR') : null,
              tone: Tone.bad,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (list.items.isEmpty)
          EmptyState(
            message: page.year == null
                ? 'Belum ada transaksi.'
                : 'Tidak ada transaksi pada $scope.',
          )
        else
          for (final row in list.items) ...[
            _Row(
              row: row,
              account: account,
              onEdit: () => showTransactionForm(
                context,
                account: account,
                editing: row,
                balance: totals.balance,
              ),
              onDelete: () => _delete(account, row),
            ),
            const SizedBox(height: 8),
          ],
        if (list.loadingMore) const Shimmer(child: SkeletonRow()),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({
    required this.row,
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final FundTransaction row;
  final AccountBrief account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = row.isDeposit ? AppColors.success : AppColors.destructive;
    final idr = toIdr(row.amount, row.rateIdr, account.currency);

    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          if (row.hasProof)
            ProofThumbnail(account: account.id, row: row)
          else
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '—',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.isDeposit ? 'Deposit' : 'Withdrawal',
                  style: TextStyle(fontSize: 14, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    longDate(row.occurredAt),
                    if ((row.note ?? '').isNotEmpty) row.note!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(row.signed, account.currency, signed: true),
                style: mono(size: 13, color: color),
              ),
              if (account.currency != 'IDR')
                Text(
                  '${money(idr, 'IDR')}${row.rateIdr == null ? '' : ' @ ${price(row.rateIdr)}'}',
                  style: mono(size: 10.5, color: AppColors.mutedForeground),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.mutedForeground,
            ),
            onSelected: (value) => switch (value) {
              'edit' => onEdit(),
              'download' => downloadProof(context, ref, account.id, row),
              _ => onDelete(),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Ubah')),
              if (row.hasProof)
                const PopupMenuItem(
                  value: 'download',
                  child: Text('Unduh bukti'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Hapus',
                  style: TextStyle(color: AppColors.destructive),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simpan bukti transfer ke galeri ponsel, di album "Trade History".
Future<void> downloadProof(
  BuildContext context,
  WidgetRef ref,
  int account,
  FundTransaction row,
) async {
  final api = ref.read(journalProvider);

  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      if (context.mounted) {
        showMessage(
          context,
          'Izin galeri ditolak. Izinkan dari pengaturan aplikasi.',
          error: true,
        );
      }
      return;
    }

    await Gal.putImageBytes(
      await api.proofBytes(account, row.id),
      album: 'Trade History',
      name: 'bukti-${row.type}-${isoDate(row.occurredAt)}',
    );

    if (context.mounted) showMessage(context, 'Bukti disimpan ke galeri.');
  } on ApiException catch (error) {
    if (context.mounted) showMessage(context, error.message, error: true);
  } on GalException catch (error) {
    if (context.mounted) {
      showMessage(context, switch (error.type) {
        GalExceptionType.accessDenied => 'Izin galeri ditolak.',
        GalExceptionType.notEnoughSpace => 'Penyimpanan ponsel penuh.',
        GalExceptionType.notSupportedFormat => 'Format gambar tidak didukung.',
        GalExceptionType.unexpected => 'Gagal menyimpan ke galeri.',
      }, error: true);
    }
  }
}

/// Bukti transfer dari disk privat server — hanya keluar dengan token pemiliknya.
class ProofThumbnail extends ConsumerWidget {
  const ProofThumbnail({
    super.key,
    required this.account,
    required this.row,
    this.size = 44,
  });

  final int account;
  final FundTransaction row;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(journalProvider);
    // Versinya ikut di alamat: bukti yang baru diganti langsung tampil, bukan
    // gambar lama dari cache.
    final url = api.proofUrl(account, row.id, row.proofVersion);
    final headers = api.client.imageHeaders;

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          // Scaffold sendiri: pesan "disimpan ke galeri" tampil di atas
          // gambar, bukan di halaman yang tertutup dialog ini.
          child: Scaffold(
            backgroundColor: Colors.black,
            // Seluas layar: body Scaffold hanya menerima batas longgar, dan
            // tanpa ini Stack menyusut setinggi baris tombol di atas —
            // gambarnya ikut terjepit kecil di situ.
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.network(
                      url,
                      headers: headers,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Unduh',
                        onPressed: () =>
                            downloadProof(context, ref, account, row),
                        icon: const Icon(
                          Icons.download_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          headers: headers,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox.square(
            dimension: size,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
