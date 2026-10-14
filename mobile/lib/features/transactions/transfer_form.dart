import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../widgets/common.dart';

/// Pindah dana dari akun yang sedang dibuka ke akun lain. Server mencatatnya
/// sebagai withdrawal di sini dan deposit di akun tujuan sekaligus, jadi
/// saldo kedua akun langsung cocok tanpa dua kali mencatat.
Future<void> showTransferForm(
  BuildContext context, {
  required AccountBrief account,
  required List<AccountBrief> targets,
  double? balance,
}) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _TransferForm(account: account, targets: targets, balance: balance),
);

class _TransferForm extends ConsumerStatefulWidget {
  const _TransferForm({
    required this.account,
    required this.targets,
    this.balance,
  });

  final AccountBrief account;

  /// Akun lain yang bisa menerima — tanpa akun asal dan tanpa arsip.
  final List<AccountBrief> targets;

  /// Saldo akun asal sekarang: isian bawaan (seluruh saldo) sekaligus batasnya.
  final double? balance;

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<_TransferForm> {
  late int _to = widget.targets.first.id;

  // Bawaannya seluruh saldo — itu yang paling sering dipindah. Dibulatkan dulu:
  // saldo dari server jumlahan float, bisa 17653.120000000003, dan angka
  // seperti itu ditolak sebagai "melebihi saldo".
  late final _all = (widget.balance ?? 0) > 0
      ? inputNumber(rounded(widget.balance!))
      : '';
  late final _amount = TextEditingController(text: _all);

  /// Jumlah yang masuk di akun tujuan — hanya diisi lintas dolar ↔ rupiah.
  final _received = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  Map<String, String> _errors = {};
  bool _busy = false;

  String get _from => widget.account.currency;

  AccountBrief get _target =>
      widget.targets.firstWhere((account) => account.id == _to);

  /// Dolar ↔ rupiah: jumlah yang masuk di akun tujuan diisi sendiri dan
  /// kursnya dihitung dari situ. Sekeluarga (USC → USD) jumlahnya sudah pasti.
  bool get _crosses => needsRate(_from) != needsRate(_target.currency);

  @override
  void initState() {
    super.initState();
    _watch(_amount, 'amount');
    _watch(_received, 'received');
  }

  /// Galat sebuah kolom hilang begitu isinya diubah: selama galat tampil,
  /// helper di bawahnya — termasuk kurs otomatis — disembunyikan Flutter.
  void _watch(TextEditingController controller, String key) {
    var last = controller.text;

    controller.addListener(() {
      final changed = controller.text != last;
      last = controller.text;

      setState(() {
        if (changed && _errors.containsKey(key)) {
          _errors = {..._errors}..remove(key);
        }
      });
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseAmount(_amount.text, _from);
    final received = parseAmount(_received.text, _target.currency);
    final rate = impliedRate(amount, _from, received, _target.currency);
    final invalid = {
      ...requiredErrors({
        'amount': _amount.text,
        if (_crosses) 'received': _received.text,
      }),
      for (final (key, controller, currency) in [
        ('amount', _amount, _from),
        ('received', _received, _target.currency),
      ])
        if (controller.text.trim().isNotEmpty &&
            (parseAmount(controller.text, currency) ?? 0) <= 0)
          key: 'Harus angka lebih dari 0.',
      // Kurs nol atau semiliar lebih hampir pasti salah ketik salah satu angka.
      if (rate != null && (rate <= 0 || rate >= 1e10))
        'received': 'Tidak masuk akal untuk jumlah yang dikirim.',
    };

    if (invalid.isNotEmpty) {
      setState(() => _errors = invalid);
      return;
    }

    setState(() {
      _busy = true;
      _errors = {};
    });

    try {
      final message = await ref
          .read(journalProvider)
          .transfer(widget.account.id, {
            'to_account_id': _to,
            'amount': amount,
            if (_crosses) 'received': received,
            'occurred_at': isoDate(_date),
            'note': _note.text.trim(),
          });

      ref.read(revisionProvider.notifier).bump();

      if (mounted) {
        showMessage(context, message);
        Navigator.pop(context);
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
    final target = _target;
    final amount = parseAmount(_amount.text, _from);
    final received = _crosses
        ? parseAmount(_received.text, target.currency)
        : convertAmount(amount, _from, target.currency, null);
    final rate = impliedRate(amount, _from, received, target.currency);
    final balance = widget.balance;
    final dollar = rateCurrency(needsRate(_from) ? _from : target.currency);

    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'Transfer antar akun',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Caption(
              'Dicatat sebagai withdrawal di ${widget.account.name} dan '
              'deposit di akun tujuan sekaligus.',
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Dari akun'),
              child: Text(
                '${widget.account.name} · $_from',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 14),
            SelectField<int>(
              label: 'Ke akun *',
              value: _to,
              errorText: _errors['to_account_id'],
              options: [
                for (final account in widget.targets)
                  (account.id, '${account.name} · ${account.currency}'),
              ],
              onChanged: (value) => setState(() {
                final before = _target.currency;
                _to = value;
                // Jumlah diterima hanya berarti untuk mata uang tujuannya.
                if (_target.currency != before) _received.clear();
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: mono(size: 14),
              decoration: InputDecoration(
                labelText: 'Jumlah dikirim ($_from) *',
                errorText: _errors['amount'],
                helperText: balance == null
                    ? null
                    : 'Saldo ${widget.account.name}: ${money(balance, _from)}.',
                // Kembali ke seluruh saldo setelah jumlahnya diubah.
                suffixIcon: balance == null || balance <= 0
                    ? null
                    : TextButton(
                        onPressed: _busy ? null : () => _amount.text = _all,
                        child: const Text('Semua'),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            if (_crosses)
              TextField(
                controller: _received,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: mono(size: 14),
                decoration: InputDecoration(
                  labelText: 'Jumlah diterima (${target.currency}) *',
                  errorText: _errors['received'],
                  helperText: rate == null
                      ? 'Yang masuk di ${target.name} — kursnya dihitung otomatis.'
                      : 'Kurs otomatis: 1 $dollar = Rp ${exchangeRate(rate)}',
                ),
              )
            else
              // Sekeluarga: yang sampai di akun tujuan sudah pasti — USC ke
              // USD dibagi seratus, IDR ke IDC dikali seratus.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(kRadius - 2),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: .25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Caption('Diterima di ${target.name}'),
                    const SizedBox(height: 2),
                    Text(
                      received == null
                          ? '—'
                          : money(received, target.currency, signed: true),
                      style: mono(
                        size: 16,
                        weight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal *',
                  errorText: _errors['occurred_at'],
                  suffixIcon: const Icon(Icons.event, size: 18),
                ),
                child: Text(longDate(_date)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: 'Catatan',
                hintText: 'Pindah modal',
                errorText: _errors['note'],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const Spacer(),
                BusyButton(
                  busy: _busy,
                  label: _busy ? 'Memindahkan…' : 'Transfer',
                  icon: Icons.swap_horiz,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
