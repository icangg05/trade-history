import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../widgets/common.dart';

final accountsProvider = FutureProvider.autoDispose<AccountsPage>((ref) {
  ref.watch(revisionProvider);

  return ref.watch(journalProvider).accounts();
});

/// Akun trading. Tiap akun punya riwayat dan aturan sendiri; ini juga
/// satu-satunya layar yang menjumlahkan seluruh akun (per mata uang).
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
    final active = ref.watch(currentAccountProvider).value?.id;

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
          builder: (page) => ListView(
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
                Opacity(
                  opacity: row.isArchived ? .6 : 1,
                  child: Panel(
                    borderColor: row.id == active
                        ? AppColors.gold.withValues(alpha: .4)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (row.id == active) const _Pill('Aktif'),
                            if (row.isArchived)
                              const _Pill(
                                'Arsip',
                                color: AppColors.mutedForeground,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Caption(
                          [
                            row.broker ?? 'Tanpa broker',
                            if ((row.accountNumber ?? '').isNotEmpty)
                              row.accountNumber!,
                            row.currency,
                            '${row.trades} trade',
                          ].join(' · '),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          money(row.balance, row.currency),
                          style: mono(size: 18, weight: FontWeight.w600),
                        ),
                        Text(
                          '${money(row.netPnl, row.currency, signed: true)} dari trading',
                          style: mono(size: 12, color: pnlColor(row.netPnl)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (row.id != active && !row.isArchived)
                              OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(selectedAccountProvider.notifier)
                                      .select(row.id);
                                  context.go('/');
                                },
                                child: const Text('Buka'),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Ubah',
                              onPressed: () =>
                                  showAccountForm(context, editing: row),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              onPressed: () => _delete(context, ref, row),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.destructive,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.color = AppColors.gold});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: TextStyle(fontSize: 10.5, color: color)),
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
  late final _balance = TextEditingController(
    text: inputNumber(widget.editing?.initialBalance ?? 0),
  );
  late String _currency = widget.editing?.currency ?? 'USD';
  late DateTime _startedAt = widget.editing?.startedAt ?? DateTime.now();
  late bool _archived = widget.editing?.isArchived ?? false;

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final controller in [_name, _broker, _number, _balance]) {
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
          'initial_balance': parseDecimal(_balance.text),
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

      showMessage(context, message);
      Navigator.pop(context);
      if (id != null) router.go('/');
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
          const Caption(
            'Saldo awal dan tanggal mulai jadi titik nol kurva perkembangan akun.',
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
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _currency,
            decoration: InputDecoration(
              labelText: 'Mata uang *',
              errorText: _errors['currency'],
            ),
            items: [
              for (final (code, label) in currencies)
                DropdownMenuItem(value: code, child: Text(label)),
            ],
            onChanged: (value) => setState(() => _currency = value ?? 'USD'),
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: mono(size: 14),
                  decoration: InputDecoration(
                    labelText: 'Saldo awal ($_currency) *',
                    hintText: '10000',
                    errorText: _errors['initial_balance'],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
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
              ),
            ],
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
