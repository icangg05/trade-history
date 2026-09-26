import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../transactions/transaction_form.dart';

/// Daftar akun beserta id akun yang sedang dibuka, sebagai satu snapshot.
/// Setelah arsip diubah keduanya dimuat ulang; kalau ditampilkan terpisah,
/// kartu berganti dua kali (tombol "Buka" muncul lalu hilang, pil "Aktif"
/// dan "Arsip" sempat bersamaan).
final accountsProvider = FutureProvider.autoDispose<(AccountsPage, int?)>((
  ref,
) async {
  ref.watch(revisionProvider);

  final (page, current) = await (
    ref.watch(journalProvider).accounts(),
    ref.watch(currentAccountProvider.future),
  ).wait;

  return (page, current?.id);
});

/// Akun trading. Tiap akun punya riwayat dan aturan sendiri; ini juga
/// satu-satunya layar yang menjumlahkan seluruh akun (per mata uang).
/// Satu kartu akun: nama & tombol ubah/hapus, broker, saldo & P/L.
const _accountCard = Panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Bone(width: 140, height: 14),
          Spacer(),
          Bone(width: 18, height: 18),
          SizedBox(width: 22),
          Bone(width: 18, height: 18),
        ],
      ),
      SizedBox(height: 10),
      Bone(width: 200, height: 9),
      SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 130, height: 18),
                SizedBox(height: 6),
                Bone(width: 110, height: 10),
              ],
            ),
          ),
          SkeletonField(width: 72),
        ],
      ),
    ],
  ),
);

const _loading = SkeletonView(
  children: [
    Bone(width: 220, height: 10),
    _accountCard,
    _accountCard,
    _accountCard,
  ],
);

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _after(WidgetRef ref) async {
    ref.invalidate(meProvider);
    ref.read(revisionProvider.notifier).bump();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AccountRow row,
  ) async {
    final ok = await confirmWithCode(
      context,
      title: 'Hapus akun ${row.name}?',
      description:
          '${row.trades} trade, seluruh transaksi dana, bukti transfer, aturan, dan analisa akun ini hilang permanen.',
      confirmLabel: 'Hapus akun',
    );

    if (!ok) return;

    try {
      final message = await ref.read(journalProvider).deleteAccount(row.id);

      await _after(ref);
      if (context.mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun trading')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Akun baru'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(accountsProvider.future),
        child: AsyncView(
          value: ref.watch(accountsProvider),
          onRetry: () => ref.invalidate(accountsProvider),
          loading: _loading,
          builder: (data) {
            final (page, active) = data;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                const Caption('Tiap akun punya riwayat dan aturan sendiri.'),
                const SizedBox(height: 12),
                if (page.items.isEmpty)
                  const EmptyState(
                    message:
                        'Belum ada akun. Buat satu untuk mulai mencatat trade.',
                  ),
                // Dengan satu akun kartu total cuma mengulang kartu di bawahnya.
                if (page.items.length > 1) ...[
                  StatGrid(
                    children: [
                      for (final total in page.totals)
                        StatCard(
                          label: 'Total ${total.currency}',
                          value: money(total.balance, total.currency),
                          hint:
                              '${money(total.netPnl, total.currency, signed: true)} dari trading · '
                              '${total.trades} trade · ${total.accounts} akun',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                for (final row in page.items) ...[
                  _AccountCard(
                    row: row,
                    active: row.id == active,
                    onOpen: () {
                      ref.read(selectedAccountProvider.notifier).select(row.id);
                      context.go('/');
                    },
                    onDelete: () => _delete(context, ref, row),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Nama, pil, dan tombol ubah/hapus satu baris; saldo dan tombol Buka di
/// bawahnya. Arsip ditandai pil "Arsip" dan nama yang diabukan, bukan seluruh
/// kartu diredupkan: opasitas 60% menjatuhkan semua teksnya ke 3:1.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.row,
    required this.active,
    required this.onOpen,
    required this.onDelete,
  });

  final AccountRow row;
  final bool active;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.fromLTRB(16, 6, 6, 14),
    borderColor: active ? AppColors.gold.withValues(alpha: .4) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: row.isArchived ? AppColors.mutedForeground : null,
                ),
              ),
            ),
            if (active) const Pill('Aktif'),
            if (row.isArchived)
              const Pill('Arsip', color: AppColors.mutedForeground),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Ubah',
              visualDensity: VisualDensity.compact,
              onPressed: () => showAccountForm(context, editing: row),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Hapus',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caption(
                [
                  row.broker ?? 'Tanpa broker',
                  if ((row.accountNumber ?? '').isNotEmpty) row.accountNumber!,
                  row.currency,
                  '${row.trades} trade',
                ].join(' · '),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          money(row.balance, row.currency),
                          style: mono(size: 18, weight: FontWeight.w600),
                        ),
                        Text(
                          '${money(row.netPnl, row.currency, signed: true)} dari trading',
                          style: mono(size: 12, color: pnlColor(row.netPnl)),
                        ),
                      ],
                    ),
                  ),
                  if (!active && !row.isArchived)
                    OutlinedButton(
                      onPressed: onOpen,
                      child: const Text('Buka'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> showAccountForm(BuildContext context, {AccountRow? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      // Menutupi tab bar juga, sama seperti modal di web.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AccountForm(editing: editing),
    );

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.editing});

  final AccountRow? editing;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _broker = TextEditingController(
    text: widget.editing?.broker ?? '',
  );
  late final _number = TextEditingController(
    text: widget.editing?.accountNumber ?? '',
  );
  late String _currency = widget.editing?.currency ?? 'USD';
  late DateTime _startedAt = widget.editing?.startedAt ?? DateTime.now();
  late bool _archived = widget.editing?.isArchived ?? false;

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final controller in [_name, _broker, _number]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    try {
      final (message, id) = await ref.read(journalProvider).saveAccount(
        widget.editing?.id,
        {
          'name': _name.text.trim(),
          'broker': _broker.text.trim(),
          'account_number': _number.text.trim(),
          'currency': _currency,
          'started_at': isoDate(_startedAt),
          'is_archived': _archived,
        },
      );

      ref.invalidate(meProvider);
      ref.read(revisionProvider.notifier).bump();

      // Akun baru langsung dibuka, sama seperti di web.
      if (id != null) {
        await ref.read(selectedAccountProvider.notifier).select(id);
      }

      if (!mounted) return;

      final router = GoRouter.of(context);
      final root = Navigator.of(context, rootNavigator: true).context;

      showMessage(context, message);
      Navigator.pop(context);

      // Akun baru belum punya saldo: langsung ke Dana dan catat deposit
      // pertamanya. Ditunda satu frame supaya halamannya sudah berganti.
      if (id != null) {
        router.go('/funds');
        final account = AccountBrief(
          id: id,
          name: _name.text.trim(),
          broker: _broker.text.trim(),
          currency: _currency,
          startedAt: _startedAt,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (root.mounted) {
            showTransactionForm(root, account: account, deposit: true);
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = error.errors);
        if (error.errors.isEmpty) {
          showMessage(context, error.message, error: true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            widget.editing == null ? 'Akun baru' : 'Ubah akun',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Caption(
            widget.editing == null
                ? 'Setelah disimpan, catat deposit pertamamu. Saldo akun dimulai dari situ.'
                : 'Saldo akun berasal dari deposit, withdrawal, dan hasil trading.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Nama akun *',
              hintText: 'FTMO 10K',
              errorText: _errors['name'],
            ),
          ),
          gap,
          TextField(
            controller: _broker,
            decoration: InputDecoration(
              labelText: 'Broker',
              hintText: 'Exness',
              errorText: _errors['broker'],
            ),
          ),
          gap,
          TextField(
            controller: _number,
            decoration: InputDecoration(
              labelText: 'Nomor akun broker',
              hintText: 'Contoh: 123456789',
              errorText: _errors['account_number'],
              helperText:
                  'Dicetak di laporan tahunan. Ini yang menyambungkan laporanmu ke statement resmi broker '
                  'saat pajak minta klarifikasi.',
            ),
          ),
          gap,
          SelectField(
            label: 'Mata uang *',
            value: _currency,
            errorText: _errors['currency'],
            options: currencies,
            onChanged: (value) => setState(() => _currency = value),
          ),
          gap,
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startedAt,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 366)),
              );
              if (picked != null) setState(() => _startedAt = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Mulai *',
                errorText: _errors['started_at'],
              ),
              child: Text(
                longDate(_startedAt),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          if (widget.editing != null) ...[
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _archived,
              onChanged: (value) => setState(() => _archived = value),
              title: const Text('Arsipkan'),
              subtitle: const Caption(
                'Akun arsip tidak muncul di pengalih akun, tapi tetap ikut di laporan tahunan.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const Spacer(),
              BusyButton(busy: _busy, onPressed: _submit, label: 'Simpan'),
            ],
          ),
        ],
      ),
    );
  }
}
