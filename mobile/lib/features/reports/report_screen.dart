import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/journal.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

/// Kanal ke `MainActivity.kt`: menulis ke folder Download publik.
const _downloads = MethodChannel('trade_history/downloads');

final _reportProvider = FutureProvider.autoDispose<ReportOptions>(
  (ref) => ref.watch(journalProvider).reportOptions(),
);

/// Laporan tahunan untuk pajak: PDF A4 landscape berisi rekonsiliasi saldo,
/// rekap bulanan, mutasi dana, dan lampiran seluruh trade. Semua akun ikut,
/// termasuk yang diarsipkan.
/// Keterangan, periode & kurs, identitas, akun yang ikut, tombol unduh.
const _loading = SkeletonView(
  children: [
    SkeletonLines(lines: 3),
    SkeletonPanel(child: SkeletonFields(count: 3)),
    SkeletonPanel(child: SkeletonFields(count: 3)),
    SkeletonPanel(child: SkeletonLines(lines: 3)),
    SkeletonField(),
  ],
);

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Laporan tahunan')),
    body: AsyncView(
      value: ref.watch(_reportProvider),
      onRetry: () => ref.invalidate(_reportProvider),
      loading: _loading,
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
  // NPWP, alamat, dan kurs tersimpan di ponsel ini saja — tidak ada NPWP yang
  // menginap di basis data hanya untuk mengisi satu kop laporan. Namanya
  // selalu nama profil; server tidak menerima nama lain.
  late final _prefs = ref.read(prefsProvider);

  late int _year = _prefs.getInt('report.year') ?? widget.options.years.first;
  late DateTime _rateDate = _endOfYear(_year);
  late final _rate = TextEditingController(
    text: _prefs.getString('report.rate') ?? '',
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
    for (final controller in [_rate, _npwp, _address]) {
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
      _prefs.setString('report.npwp', _npwp.text),
      _prefs.setString('report.address', _address.text),
    ]);

    try {
      final bytes = await ref.read(journalProvider).reportPdf({
        'year': _year,
        // Dikirim apa adanya: server yang membaca koma sebagai desimal.
        'rate': _rate.text.trim(),
        'rate_date': isoDate(_rateDate),
        'npwp': _npwp.text.trim(),
        'address': _address.text.trim(),
      });

      final slug = widget.options.defaultName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final name = 'laporan-trading-$_year-$slug.pdf';

      try {
        await _downloads.invokeMethod('save', {
          'name': name,
          'mime': 'application/pdf',
          'bytes': bytes,
        });
        if (mounted) {
          showMessage(context, '$name tersimpan di folder Download.');
        }
        return;
      } on MissingPluginException {
        // iOS dan Android 9 ke bawah: tidak ada folder Download bersama yang
        // bisa ditulis tanpa izin — pakai lembar bagikan (ada "Simpan ke File").
      } on PlatformException catch (error) {
        debugPrint('Simpan ke Download gagal: ${error.message}');
      }

      final file = File('${(await getTemporaryDirectory()).path}/$name');

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
          'Rekap satu tahun pajak dalam PDF: saldo, rekap bulanan, mutasi dana, dan semua trade '
          'dari semua akun, termasuk yang diarsipkan.',
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Periode & kurs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectField(
                label: 'Tahun pajak',
                value: _year,
                errorText: _errors['year'],
                options: [
                  for (final year in widget.options.years) (year, '$year'),
                ],
                // Tanggal kurs ikut pindah: tanggal tahun lalu yang tersimpan
                // akan tercetak diam-diam di laporan tahun ini kalau tidak.
                onChanged: (value) => setState(() {
                  _year = value;
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
                'Pakai kurs resmi, misalnya kurs pajak KMK akhir tahun. Kurs ini hanya untuk laba/rugi '
                'trading; deposit dan withdrawal memakai kurs di hari transaksinya.',
              ),
              if (!_foreign) ...[
                const SizedBox(height: 6),
                const Caption(
                  'Semua akunmu dalam rupiah, jadi kurs tidak berpengaruh.',
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
                'Nama dari profil. NPWP dan alamat tersimpan di ponsel ini saja.',
              ),
              gap,
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Nama'),
                child: Text(widget.options.defaultName),
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
