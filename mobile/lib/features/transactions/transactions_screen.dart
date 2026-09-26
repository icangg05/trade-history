import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/journal.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/skeleton.dart';
import 'transaction_form.dart';

/// Filter periode: tahun + bulan, atau `all`. Bulan hanya berarti kalau
/// tahunnya juga dipilih — "Agustus" lintas tahun bukan angka yang berarti.
typedef FundsQuery = (int account, String year, String month);

/// Keterangan, pilihan tahun + bulan, kartu saldo, lalu baris transaksi.
const _loading = SkeletonView(
  children: [
    Bone(width: 240, height: 10),
    Row(
      children: [
        Expanded(child: SkeletonField()),
        SizedBox(width: 10),
        Expanded(child: SkeletonField()),
      ],
    ),
    SkeletonStats(),
    SkeletonRows(count: 5),
  ],
);

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
    loading: _loading,
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
          loading: _loading,
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

    final rows = list.items;
    final header = <Widget>[
      const Caption('Arus dana masuk-keluar, terpisah dari hasil trading.'),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: SelectField(
              label: 'Tahun',
              value: _year,
              options: [
                ('all', 'Semua tahun'),
                for (final year in page.years) ('$year', '$year'),
              ],
              onChanged: (value) => setState(() => _year = value),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Bulan ikut terkunci ke "semua" selama tahunnya "semua".
            child: SelectField(
              label: 'Bulan',
              value: _year == 'all' ? 'all' : _month,
              enabled: _year != 'all',
              options: [
                ('all', 'Semua bulan'),
                for (var month = 1; month <= 12; month++)
                  (
                    '$month',
                    monthLabel(
                      '2000-${'$month'.padLeft(2, '0')}',
                    ).split(' ').first,
                  ),
              ],
              onChanged: (value) => setState(() => _month = value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      StatCard(
        label: 'Saldo sekarang',
        value: money(totals.balance, currency),
        tone: Tone.gold,
      ),
      const SizedBox(height: 10),
      StatGrid(
        children: [
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
      const SizedBox(height: 10),
      _Difference(
        withdrawal: totals.withdrawal,
        deposit: totals.deposit,
        currency: currency,
        scope: scope,
      ),
      const SizedBox(height: 14),
    ];
    final count = rows.isEmpty ? 1 : rows.length;

    // Builder, bukan daftar jadi: hasil gulir tanpa ujung bisa ratusan baris,
    // masing-masing dengan gambar bukti. Yang dibangun hanya yang dekat layar.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: header.length + count + (list.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];

        final at = index - header.length;

        if (at >= count) {
          // Beberapa baris, bukan satu: halaman berikutnya memang berisi banyak.
          return const Shimmer(child: SkeletonRows());
        }

        if (rows.isEmpty) {
          return EmptyState(
            message: page.year == null
                ? 'Belum ada transaksi.'
                : 'Tidak ada transaksi pada $scope.',
          );
        }

        final row = rows[at];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Row(
            key: ValueKey(row.id),
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
        );
      },
    );
  }
}

/// Withdrawal dikurangi deposit. Kalau uang yang sudah ditarik melebihi yang
/// disetor, modalnya sudah kembali dan sisa saldonya untung. Kalau kebalikannya,
/// penarikan belum menutup setoran.
class _Difference extends StatelessWidget {
  const _Difference({
    required this.withdrawal,
    required this.deposit,
    required this.currency,
    required this.scope,
  });

  final double withdrawal;
  final double deposit;
  final String currency;
  final String scope;

  @override
  Widget build(BuildContext context) {
    final net = withdrawal - deposit;

    return StatCard(
      label: 'Selisih WD − deposit · $scope',
      value: money(net, currency, signed: true),
      hint: net > 0
          ? 'Penarikan sudah melebihi setoran. Modal sudah kembali, selebihnya untung.'
          : net < 0
          ? 'Setoran masih lebih besar dari penarikan. Modal belum kembali sepenuhnya.'
          : 'Penarikan sama dengan setoran. Modal baru kembali pas.',
      tone: net > 0 ? Tone.good : (net < 0 ? Tone.bad : Tone.plain),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({
    super.key,
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
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    await saveToGallery(
      context,
      () => ref
          .read(journalProvider)
          .proofBytes(widget.account.id, widget.row.id),
      _proofName(widget.row),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final account = widget.account;
    final color = row.isDeposit ? AppColors.success : AppColors.destructive;
    final idr = toIdr(row.amount, row.rateIdr, account.currency);
    // Huruf sistem besar: nominal pindah ke bawah keterangan, jadi kata
    // "Withdrawal" tidak terjepit jadi satu huruf per baris.
    final stacked = largeText(context);
    final amounts = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          money(row.signed, account.currency, signed: true),
          style: mono(size: 13, color: color),
        ),
        if (account.currency != 'IDR')
          Text(
            '${money(idr, 'IDR')}${row.rateIdr == null ? '' : ' @ ${price(row.rateIdr)}'}',
            style: mono(size: 11, color: AppColors.mutedForeground),
          ),
      ],
    );

    return Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showDetail(
          context,
          account: account,
          row: row,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              if (row.hasProof)
                ProofThumbnail(account: account.id, row: row)
              else
                Container(
                  width: 44,
                  height: 44,
                  // Setara area ketuk thumbnail bukti, supaya barisnya sejajar.
                  margin: const EdgeInsets.all(2),
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
                    if (stacked) ...[const SizedBox(height: 4), amounts],
                  ],
                ),
              ),
              if (!stacked) amounts,
              // Selama bukti diunduh, titik tiganya jadi putaran dan menunya
              // terkunci — tidak ada unduhan ganda.
              PopupMenuButton<String>(
                enabled: !_saving,
                tooltip: _saving ? 'Mengunduh bukti…' : null,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                onSelected: (value) => switch (value) {
                  'edit' => widget.onEdit(),
                  'download' => _download(),
                  _ => widget.onDelete(),
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
        ),
      ),
    );
  }
}

/// Detail satu transaksi. Baris di daftar memotong catatan jadi dua baris dan
/// buktinya jadi thumbnail kecil; di sini semuanya tampil utuh.
Future<void> _showDetail(
  BuildContext context, {
  required AccountBrief account,
  required FundTransaction row,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheet) {
    final currency = account.currency;
    final color = row.isDeposit ? AppColors.success : AppColors.destructive;

    // Sheet ditutup dulu: form ubah dan konfirmasi hapus muncul di atas
    // halaman Dana, bukan menumpuk di atas detail ini.
    void close(VoidCallback action) {
      Navigator.pop(sheet);
      action();
    }

    Widget fact(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption(label),
        const SizedBox(height: 2),
        Text(value, style: mono(size: 13)),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row.isDeposit ? 'Deposit' : 'Withdrawal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Caption(longDate(row.occurredAt)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(kRadius - 2),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Text(
              money(row.signed, currency, signed: true),
              style: mono(size: 18, weight: FontWeight.w600, color: color),
            ),
          ),
          if (currency != 'IDR') ...[
            const SizedBox(height: 14),
            FieldPair(
              fact('Kurs', row.rateIdr == null ? '—' : price(row.rateIdr)),
              fact(
                'Setara rupiah',
                money(toIdr(row.amount, row.rateIdr, currency), 'IDR'),
              ),
              minWidth: 100,
            ),
          ],
          if ((row.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            const Caption('Catatan'),
            const SizedBox(height: 2),
            Text(row.note!, style: const TextStyle(fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          const Caption('Bukti transfer'),
          const SizedBox(height: 6),
          if (row.hasProof)
            Align(
              alignment: Alignment.centerLeft,
              child: ProofThumbnail(account: account.id, row: row, size: 120),
            )
          else
            const Text(
              'Tidak ada bukti transfer.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedForeground,
              ),
            ),
          const Divider(height: 24),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => close(onDelete),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => close(onEdit),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Ubah'),
              ),
            ],
          ),
        ],
      ),
    );
  },
);

/// Nama berkas bukti transfer saat disimpan ke galeri.
String _proofName(FundTransaction row) =>
    'bukti-${row.type}-${isoDate(row.occurredAt)}';

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

    return Semantics(
      button: true,
      label: 'Bukti transfer, ketuk untuk memperbesar',
      excludeSemantics: true,
      child: GestureDetector(
        // Area ketuk minimal 48 dp walau gambarnya lebih kecil.
        behavior: HitTestBehavior.opaque,
        onTap: () => showImageViewer(
          context,
          image: NetworkImage(url, headers: headers),
          bytes: () => api.proofBytes(account, row.id),
          name: _proofName(row),
        ),
        child: Padding(
          padding: EdgeInsets.all(size < 48 ? (48 - size) / 2 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              url,
              headers: headers,
              width: size,
              height: size,
              // Didekode seukuran thumbnail, bukan resolusi penuh buktinya.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
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
        ),
      ),
    );
  }
}
