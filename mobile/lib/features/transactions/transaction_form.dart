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
import '../../widgets/image_viewer.dart';
import 'transactions_screen.dart';

/// Catat atau perbaiki setoran/penarikan. Bukti transfer wajib saat dicatat —
/// ini catatan uang sungguhan — dan opsional saat diperbaiki.
Future<void> showTransactionForm(
  BuildContext context, {
  required AccountBrief account,
  FundTransaction? editing,
  double? balance,
  bool deposit = false,
}) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  // Seret-tutup memanggil Navigator.pop langsung, melewati PopScope, dan tidak
  // bisa dimatikan setelah terbuka — jadi dimatikan sejak awal supaya lembar
  // ini tidak tertutup di tengah unggahan. Tetap bisa ditutup lewat Batal,
  // ketuk latar, atau tombol kembali selama tidak sedang mengirim.
  enableDrag: false,
  builder: (_) => _TransactionForm(
    account: account,
    editing: editing,
    balance: balance,
    deposit: deposit,
  ),
);

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({
    required this.account,
    this.editing,
    this.balance,
    this.deposit = false,
  });

  final AccountBrief account;
  final FundTransaction? editing;

  /// Saldo akun sekarang — batas withdrawal. Server yang menegakkannya;
  /// di sini hanya ditampilkan supaya tidak perlu menebak.
  final double? balance;

  /// Dibuka sebagai deposit — dipakai untuk setoran pertama akun baru.
  final bool deposit;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  // Withdrawal jadi bawaan: setoran hanya sesekali, penarikan yang rutin dicatat.
  late String _type =
      widget.editing?.type ?? (widget.deposit ? 'deposit' : 'withdrawal');
  late final _amount = TextEditingController(text: _initialAmount);

  // Akun dolar: rupiah yang benar-benar disetor / diterima, persis seperti di
  // mutasi rekening. Kursnya dihitung dari angka ini, bukan diketik sendiri.
  late final _rupiah = TextEditingController(text: _initialRupiah);

  late final _initialAmount = inputNumber(widget.editing?.amount);
  late final _initialRupiah = () {
    final rate = widget.editing?.rateIdr;
    final idr = rate == null
        ? null
        : toIdr(widget.editing!.amount, rate, _currency);

    return idr == null ? '' : inputNumber(rounded(idr));
  }();
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  late DateTime _date = widget.editing?.occurredAt ?? DateTime.now();

  /// Bukti yang sudah dikecilkan image_picker — yang tampil di pratinjau sama
  /// persis dengan yang dikirim.
  Uint8List? _proof;
  Map<String, String> _errors = {};
  bool _busy = false;

  /// Bagian yang sudah terkirim, 0–1. Setelah 1 server masih mengolah buktinya.
  double _sent = 0;

  String get _currency => widget.account.currency;

  /// Batas withdrawal. Saat memperbaiki, baris ini sendiri dikeluarkan dulu
  /// dari saldo — sama dengan hitungan server.
  double? get _available => _type != 'withdrawal' || widget.balance == null
      ? null
      : widget.balance! - (widget.editing?.signed ?? 0);

  /// Akun rupiah (IDR, IDC) tidak perlu kurs — nilainya sudah rupiah.
  bool get _needsRate => needsRate(_currency);

  /// Kurs dari jumlah akun dan rupiahnya. Selama keduanya tidak disentuh saat
  /// memperbaiki, kurs yang tercatat dipakai utuh — rupiah di kolom isian
  /// sudah dibulatkan, jadi menghitung ulang bisa menggeser desimal ketiganya.
  double? get _rate =>
      widget.editing != null &&
          _amount.text == _initialAmount &&
          _rupiah.text == _initialRupiah
      ? widget.editing!.rateIdr
      : impliedRate(
          parseAmount(_amount.text, _currency),
          _currency,
          parseAmount(_rupiah.text, 'IDR'),
          'IDR',
        );

  @override
  void initState() {
    super.initState();
    _watch(_amount, 'amount');
    _watch(_rupiah, 'rate_idr');
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
    _rupiah.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickProof(ImageSource source) async {
    // Foto kamera selalu besar (3–5 MB), jadi dikecilkan dulu supaya
    // unggahannya ringan — jangan lebih kecil dari 2000 px, bukti ini masuk
    // laporan pajak dan harus terbaca. Gambar galeri dikirim apa adanya:
    // begitu diberi batas, image_picker selalu mengodekan ulang, dan screenshot
    // yang sudah kecil malah membengkak. Server yang menormalkan keduanya.
    final camera = source == ImageSource.camera;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: camera ? 2000 : null,
      maxHeight: camera ? 2000 : null,
      imageQuality: camera ? 85 : null,
    );

    if (file == null) return;

    // Batas yang sama dengan server — ditolak di sini supaya tidak menunggu
    // unggahan yang pasti gagal. Yang kena hanya foto asli dari galeri; foto
    // lewat tombol Kamera sudah dikecilkan di atas.
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) {
        setState(
          () => _errors = {
            ..._errors,
            'proof':
                'Ukuran bukti transfer maksimal 5 MB. Pilih gambar lain atau pakai Kamera.',
          },
        );
      }
      return;
    }

    final bytes = await file.readAsBytes();

    if (mounted) {
      setState(() {
        _proof = bytes;
        _errors = {..._errors}..remove('proof');
      });
    }
  }

  Future<void> _submit() async {
    // Dicek di sini dulu: tanpa ini buktinya terunggah penuh — bisa beberapa
    // MB — hanya untuk ditolak server karena jumlahnya kosong.
    final invalid = {
      ...requiredErrors({
        'amount': _amount.text,
        if (_needsRate) 'rate_idr': _rupiah.text,
      }),
      for (final (key, controller, currency) in [
        ('amount', _amount, _currency),
        ('rate_idr', _rupiah, 'IDR'),
      ])
        if (controller.text.trim().isNotEmpty &&
            (parseAmount(controller.text, currency) ?? 0) <= 0)
          key: 'Harus angka lebih dari 0.',
      // Kurs nol atau semiliar lebih hampir pasti salah ketik salah satu angka.
      if (_needsRate && _rate != null && (_rate! <= 0 || _rate! >= 1e10))
        'rate_idr': 'Tidak cocok dengan jumlah di atas.',
      if (widget.editing == null && _proof == null) 'proof': 'Wajib diisi.',
    };

    if (invalid.isNotEmpty) {
      setState(() => _errors = invalid);
      return;
    }

    setState(() {
      _busy = true;
      _sent = 0;
      _errors = {};
    });

    try {
      final message = await ref
          .read(journalProvider)
          .saveTransaction(
            widget.account.id,
            widget.editing?.id,
            {
              'type': _type,
              'amount': parseAmount(_amount.text, _currency),
              'rate_idr': _needsRate ? _rate : null,
              'occurred_at': isoDate(_date),
              'note': _note.text.trim(),
            },
            proof: _proof,
            onProgress: (sent, total) {
              if (total > 0 && mounted) setState(() => _sent = sent / total);
            },
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
    final idr = toIdr(parseAmount(_amount.text, _currency), null, _currency);
    final rate = _rate;
    // Akun sen rupiah tidak punya kolom kurs, jadi setara rupiahnya ikut di
    // bawah jumlah — 1.000.000 IDC baru Rp10.000.
    final hints = [
      if (_available != null)
        'Bisa ditarik paling banyak ${money(_available, _currency)}.',
      if (!_needsRate && _currency != 'IDR' && idr != null)
        'Setara ${money(idr, 'IDR')}.',
    ];

    // Selama mengirim, tombol kembali dan ketuk latar tidak menutup lembar ini.
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          // Tanpa pegangan seret (enableDrag: false), jadi jarak atasnya sendiri.
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: mono(size: 14),
              decoration: InputDecoration(
                labelText: 'Jumlah ($_currency) *',
                hintText: '500',
                errorText: _errors['amount'],
                helperText: hints.isEmpty ? null : hints.join('\n'),
                helperMaxLines: 2,
              ),
            ),
            if (_needsRate) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _rupiah,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: mono(size: 14),
                decoration: InputDecoration(
                  labelText: _type == 'deposit'
                      ? 'Rupiah yang disetor *'
                      : 'Rupiah yang diterima *',
                  hintText: '1625000',
                  errorText: _errors['rate_idr'],
                  helperText: rate == null
                      ? 'Sesuai mutasi rekening — kursnya dihitung otomatis.'
                      : 'Kurs otomatis: 1 ${rateCurrency(_currency)} = Rp ${exchangeRate(rate)}',
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
            // Kotaknya sendiri bisa diketuk — sama dengan tombol Galeri.
            InkWell(
              onTap: _busy ? null : () => _pickProof(ImageSource.gallery),
              borderRadius: BorderRadius.circular(kRadius - 2),
              child: Container(
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
                // Pratinjau didekode kecil; ketuk untuk melihat ukuran asli.
                child: _proof != null
                    ? GestureDetector(
                        onTap: () => showImageViewer(
                          context,
                          image: MemoryImage(_proof!),
                          bytes: () async => _proof!,
                          name: 'bukti-$_type-${isoDate(_date)}',
                        ),
                        child: Image.memory(
                          _proof!,
                          height: 180,
                          cacheHeight:
                              (180 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          fit: BoxFit.contain,
                        ),
                      )
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
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // Mati selama mengirim: bukti yang sedang diunggah
                    // tidak boleh tertukar di tengah jalan.
                    onPressed: _busy
                        ? null
                        : () => _pickProof(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickProof(ImageSource.camera),
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
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const Spacer(),
                // Persen hanya kalau ada bukti yang diunggah; setelah penuh
                // server masih mengolah gambarnya.
                BusyButton(
                  busy: _busy,
                  label: _busy ? 'Menyimpan…' : 'Simpan',
                  progress: _proof == null ? null : _sent,
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
