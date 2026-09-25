import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/journal.dart';
import '../../widgets/common.dart';

final _reportProvider = FutureProvider.autoDispose<ReportOptions>(
  (ref) => ref.watch(journalProvider).reportOptions(),
);

/// Laporan tahunan untuk pajak: PDF A4 landscape berisi rekonsiliasi saldo,
/// rekap bulanan, mutasi dana, dan lampiran seluruh trade. Semua akun ikut,
/// termasuk yang diarsipkan.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Laporan tahunan')),
    body: AsyncView(
      value: ref.watch(_reportProvider),
      onRetry: () => ref.invalidate(_reportProvider),
      builder: (options) => _ReportForm(options: options),
    ),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.options});

  final ReportOptions options;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  // Identitas dan kurs tersimpan di ponsel ini saja — tidak ada NPWP yang
  // menginap di basis data hanya untuk mengisi satu kop laporan.
  late final _prefs = ref.read(prefsProvider);

  late int _year = _prefs.getInt('report.year') ?? widget.options.years.first;
  late DateTime _rateDate = _endOfYear(_year);
  late final _rate = TextEditingController(
    text: _prefs.getString('report.rate') ?? '',
  );
  late final _name = TextEditingController(
    text: _prefs.getString('report.name') ?? widget.options.defaultName,
  );
  late final _npwp = TextEditingController(
    text: _prefs.getString('report.npwp') ?? '',
  );
  late final _address = TextEditingController(
    text: _prefs.getString('report.address') ?? '',
  );

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();

    if (!widget.options.years.contains(_year)) {
      _year = widget.options.years.first;
    }
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [_rate, _name, _npwp, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Akhir tahun pajak — atau hari ini, kalau tahunnya masih berjalan.
  static DateTime _endOfYear(int year) {
    final last = DateTime(year, 12, 31);
    final today = DateTime.now();

    return last.isAfter(today)
        ? DateTime(today.year, today.month, today.day)
        : last;
  }

  bool get _foreign =>
      widget.options.accounts.any((account) => account['currency'] != 'IDR');

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    await Future.wait([
      _prefs.setInt('report.year', _year),
      _prefs.setString('report.rate', _rate.text),
      _prefs.setString('report.name', _name.text),
      _prefs.setString('report.npwp', _npwp.text),
      _prefs.setString('report.address', _address.text),
    ]);

    try {
      final bytes = await ref.read(journalProvider).reportPdf({
        'year': _year,
        // Dikirim apa adanya: server yang membaca koma sebagai desimal.
        'rate': _rate.text.trim(),
        'rate_date': isoDate(_rateDate),
        'name': _name.text.trim(),
        'npwp': _npwp.text.trim(),
        'address': _address.text.trim(),
      });

      final slug = _name.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final file = File(
        '${(await getTemporaryDirectory()).path}/laporan-trading-$_year-$slug.pdf',
      );

      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Laporan trading $_year',
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = error.errors);
        showMessage(context, error.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final parsed = parseDecimal(_rate.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const Caption(
          'Berkas PDF A4 landscape berisi rekonsiliasi saldo, rekap bulanan, mutasi dana, dan lampiran seluruh '
          'transaksi trade sepanjang satu tahun pajak, untuk dipegang saat petugas pajak meminta klarifikasi. '
          'Seluruh akun ikut, termasuk yang sudah diarsipkan.',
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Periode & kurs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _year,
                decoration: InputDecoration(
                  labelText: 'Tahun pajak',
                  errorText: _errors['year'],
                ),
                items: [
                  for (final year in widget.options.years)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                // Tanggal kurs ikut pindah: tanggal tahun lalu yang tersimpan
                // akan tercetak diam-diam di laporan tahun ini kalau tidak.
                onChanged: (value) => setState(() {
                  _year = value ?? _year;
                  _rateDate = _endOfYear(_year);
                }),
              ),
              gap,
              TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: mono(size: 14),
                decoration: InputDecoration(
                  labelText: 'Kurs rupiah per 1 USD',
                  hintText: 'Contoh: 17.757,40',
                  errorText: _errors['rate'],
                  // Hasil bacaannya ditampilkan kembali supaya salah tafsir
                  // ketahuan sebelum PDF-nya diunduh.
                  helperText: parsed == null || parsed <= 0
                      ? null
                      : 'Terbaca: Rp ${number(parsed)}',
                ),
              ),
              gap,
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _rateDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _rateDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Kurs tanggal',
                    errorText: _errors['rate_date'],
                    suffixIcon: const Icon(Icons.event, size: 18),
                  ),
                  child: Text(longDate(_rateDate)),
                ),
              ),
              const SizedBox(height: 10),
              const Caption(
                'Kurs dan tanggalnya ikut dicetak supaya bisa diperiksa ulang. Isi dengan kurs yang punya sumber '
                'resmi, misalnya kurs pajak KMK di akhir tahun. Angka ini hanya dipakai untuk laba/rugi trading; '
                'setoran dan penarikan tetap memakai kurs yang tercatat pada hari transaksinya.',
              ),
              if (!_foreign) ...[
                const SizedBox(height: 6),
                const Caption(
                  'Semua akunmu bermata uang rupiah, jadi kursnya tidak akan mengubah angka apa pun.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Identitas wajib pajak',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Caption(
                'Hanya dicetak di kop laporan. Tersimpan di ponsel ini saja.',
              ),
              gap,
              TextField(
                controller: _name,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Nama lengkap sesuai kartu identitas',
                  errorText: _errors['name'],
                  counterText: '',
                ),
              ),
              gap,
              TextField(
                controller: _npwp,
                maxLength: 32,
                decoration: InputDecoration(
                  labelText: 'NPWP (opsional)',
                  hintText: '00.000.000.0-000.000',
                  errorText: _errors['npwp'],
                  counterText: '',
                ),
              ),
              gap,
              TextField(
                controller: _address,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Alamat (opsional)',
                  hintText: 'Alamat sesuai yang terdaftar di NPWP',
                  errorText: _errors['address'],
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Akun yang ikut',
          child: Column(
            children: [
              for (final account in widget.options.accounts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: '${account['name']}',
                            children: [
                              if (account['is_archived'] == true)
                                const TextSpan(
                                  text: '  (diarsipkan)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Caption(
                        '${account['broker'] ?? '—'} · ${account['currency']}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BusyButton(
          busy: _busy,
          onPressed: _download,
          label: 'Unduh PDF',
          icon: Icons.download,
        ),
      ],
    );
  }
}
