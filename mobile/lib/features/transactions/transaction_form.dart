import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/journal.dart';
import '../../widgets/common.dart';
import 'transactions_screen.dart';

/// Catat atau perbaiki setoran/penarikan. Bukti transfer wajib saat dicatat —
/// ini catatan uang sungguhan — dan opsional saat diperbaiki.
Future<void> showTransactionForm(
  BuildContext context, {
  required AccountBrief account,
  FundTransaction? editing,
}) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _TransactionForm(account: account, editing: editing),
);

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({required this.account, this.editing});

  final AccountBrief account;
  final FundTransaction? editing;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  // Withdrawal jadi bawaan: setoran hanya sesekali, penarikan yang rutin dicatat.
  late String _type = widget.editing?.type ?? 'withdrawal';
  late final _amount = TextEditingController(
    text: inputNumber(widget.editing?.amount),
  );
  late final _rate = TextEditingController(
    text: inputNumber(widget.editing?.rateIdr),
  );
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  late DateTime _date = widget.editing?.occurredAt ?? DateTime.now();

  /// Bukti yang sudah dikecilkan image_picker — yang tampil di pratinjau sama
  /// persis dengan yang dikirim.
  Uint8List? _proof;
  Map<String, String> _errors = {};
  bool _busy = false;

  String get _currency => widget.account.currency;

  /// Akun rupiah tidak perlu kurs — nilainya sudah rupiah.
  bool get _needsRate => _currency != 'IDR';

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickProof(ImageSource source) async {
    // Hanya penghemat kuota: server tetap menormalkan ke JPEG 2000 px.
    // Jangan lebih kecil — bukti ini masuk laporan pajak dan harus terbaca.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (mounted) setState(() => _proof = bytes);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    try {
      final message = await ref.read(journalProvider).saveTransaction(
        widget.account.id,
        widget.editing?.id,
        {
          'type': _type,
          'amount': parseDecimal(_amount.text),
          'rate_idr': _needsRate ? parseDecimal(_rate.text) : null,
          'occurred_at': isoDate(_date),
          'note': _note.text.trim(),
        },
        proof: _proof,
      );

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
    final editing = widget.editing;
    final idr = toIdr(
      parseDecimal(_amount.text),
      parseDecimal(_rate.text),
      _currency,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            editing == null ? 'Catat transaksi' : 'Ubah transaksi',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Segments(
            value: _type,
            options: const [
              ('deposit', 'Deposit'),
              ('withdrawal', 'Withdrawal'),
            ],
            colors: const {
              'deposit': AppColors.success,
              'withdrawal': AppColors.destructive,
            },
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: mono(size: 14),
            decoration: InputDecoration(
              labelText: 'Jumlah ($_currency) *',
              hintText: '500',
              errorText: _errors['amount'],
            ),
          ),
          if (_needsRate) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: mono(size: 14),
              decoration: InputDecoration(
                labelText:
                    'Kurs rupiah (1 ${rateCurrency(_currency)} = Rp …) *',
                hintText: '16250',
                errorText: _errors['rate_idr'],
                helperText: idr == null
                    ? 'Kurs hari transaksi — tidak bisa direkonstruksi belakangan.'
                    : 'Setara ${money(idr, 'IDR')}',
              ),
            ),
          ],
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
          Caption(editing == null ? 'Bukti transfer *' : 'Bukti transfer'),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minHeight: 110),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius - 2),
              border: Border.all(
                color: _errors['proof'] == null
                    ? AppColors.border
                    : AppColors.destructive,
              ),
            ),
            child: _proof != null
                ? Image.memory(_proof!, height: 180, fit: BoxFit.contain)
                : (editing?.hasProof ?? false)
                ? ProofThumbnail(
                    account: widget.account.id,
                    row: editing!,
                    size: 150,
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.mutedForeground,
                      ),
                      SizedBox(height: 6),
                      Caption('Tangkapan layar mutasi rekening'),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickProof(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeri'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickProof(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Kamera'),
                ),
              ),
            ],
          ),
          if (_errors['proof'] != null) ...[
            const SizedBox(height: 6),
            Caption(_errors['proof']!, color: AppColors.destructive),
          ] else if (editing != null) ...[
            const SizedBox(height: 6),
            const Caption('Biarkan apa adanya kalau buktinya tidak berubah.'),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Catatan',
              hintText: 'Top up bulanan',
              errorText: _errors['note'],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const Spacer(),
              BusyButton(
                busy: _busy,
                label: 'Simpan',
                onPressed: editing == null && _proof == null ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
