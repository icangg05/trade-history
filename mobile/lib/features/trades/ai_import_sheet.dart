import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/trade.dart';
import '../../widgets/common.dart';

/// Hasil baca AI plus gambarnya — gambar hanya hidup di layar selama form
/// terbuka untuk dicocokkan, tidak pernah disimpan server.
typedef AiImport = ({ExtractResult result, Uint8List image});

/// Screenshot per sekali baca. Satu screenshot jadi satu trade, masing-masing
/// di tabnya sendiri di form.
const maxScreenshots = 3;

/// [max]: sisa tab yang masih boleh dibuka form, paling banyak [maxScreenshots].
Future<List<AiImport>?> showAiImport(
  BuildContext context,
  int account, {
  int max = maxScreenshots,
}) => showModalBottomSheet<List<AiImport>>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  // Selama permintaan berjalan lembar ini dikunci: menutupnya di tengah jalan
  // hanya membuang permintaan yang kuotanya sudah terlanjur terpakai.
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _AiImportSheet(account: account, max: max),
);

/// Satu screenshot yang dipilih. Hasil yang sudah terbaca ikut disimpan, jadi
/// membaca ulang hanya mengirim yang gagal — kuota Gemini tidak terbuang.
class _Shot {
  _Shot(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;
  ExtractResult? result;
  String? error;

  /// Byte terkirim / total, untuk persen gabungan di tombol.
  int sent = 0;
  int total = 0;
}

class _AiImportSheet extends ConsumerStatefulWidget {
  const _AiImportSheet({required this.account, required this.max});

  final int account;
  final int max;

  @override
  ConsumerState<_AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends ConsumerState<_AiImportSheet> {
  final List<_Shot> _shots = [];
  bool _busy = false;
  String? _error;

  int get _room => widget.max - _shots.length;

  /// Kemajuan unggah semua gambar yang sedang dikirim, 0–1. Setelah penuh
  /// giliran Gemini membaca, dan tombolnya kembali berputar.
  double get _progress {
    final sending = _shots.where((shot) => shot.total > 0);
    final total = sending.fold(0, (sum, shot) => sum + shot.total);

    return total == 0
        ? 0
        : sending.fold(0, (sum, shot) => sum + shot.sent) / total;
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final files = source == ImageSource.camera
          ? [
              ?await picker.pickImage(
                source: source,
                maxWidth: 2560,
                imageQuality: 92,
              ),
            ]
          : await picker.pickMultiImage(
              maxWidth: 2560,
              imageQuality: 92,
              limit: _room,
            );

      // Sebagian galeri mengabaikan `limit`, jadi dipotong lagi di sini.
      final shots = [
        for (final file in files.take(_room))
          _Shot(file, await file.readAsBytes()),
      ];

      if (shots.isEmpty || !mounted) return;

      setState(() {
        _shots.addAll(shots);
        _error = null;
      });
    } on Exception {
      setState(
        () =>
            _error = 'Tidak bisa membuka gambar. Periksa izin kamera / galeri.',
      );
    }
  }

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
      for (final shot in _shots) {
        shot
          ..sent = 0
          ..total = 0;
      }
    });

    final api = ref.read(journalProvider);

    Future<void> read(_Shot shot) async {
      try {
        shot.result = await api.extract(
          widget.account,
          shot.file,
          onProgress: (sent, total) {
            if (!mounted) return;
            setState(() {
              shot.sent = sent;
              shot.total = total;
            });
          },
        );
        shot.error = null;
      } on ApiException catch (error) {
        // Bukan screenshot trading, atau datanya tidak lengkap: gambarnya
        // tetap di sini dengan alasannya, bisa dibuang atau diganti.
        shot.error = error.message;
      }
    }

    // Bersamaan, bukan bergiliran: satu gambar saja makan 3–8 detik.
    await Future.wait(_shots.where((shot) => shot.result == null).map(read));

    if (!mounted) return;

    if (_shots.every((shot) => shot.result != null)) {
      Navigator.pop(context, [
        for (final shot in _shots) (result: shot.result!, image: shot.bytes),
      ]);
    } else {
      setState(() => _busy = false);
    }
  }

  Widget _tile(int index) {
    final shot = _shots[index];
    final color = shot.error != null
        ? AppColors.destructive
        : shot.result != null
        ? AppColors.success
        : AppColors.border;

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(shot.bytes, fit: BoxFit.cover, cacheWidth: 400),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color,
              width: color == AppColors.border ? 1 : 2,
            ),
          ),
        ),
        Positioned(left: 6, bottom: 6, child: _Badge('${index + 1}')),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filled(
            tooltip: 'Buang gambar ${index + 1}',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            onPressed: _busy ? null : () => setState(() => _shots.remove(shot)),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final errors = [
      for (final (index, shot) in _shots.indexed)
        if (shot.error != null) 'Gambar ${index + 1}: ${shot.error}',
      ?_error,
    ];
    final unread = _shots.where((shot) => shot.result == null).length;

    return PopScope(
      canPop: !_busy,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Baca screenshot dengan AI',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Caption(
            'Unggah layar posisi atau riwayat order yang memuat entry, SL, dan TP'
            '${widget.max > 1 ? ', sampai ${widget.max} gambar sekaligus. Satu gambar jadi satu trade' : ''}. '
            'Hasilnya mengisi form, periksa dulu sebelum disimpan.',
          ),
          const SizedBox(height: 16),
          if (_shots.isEmpty)
            // Kotaknya sendiri bisa diketuk — sama dengan tombol Galeri.
            InkWell(
              onTap: _busy ? null : () => _pick(ImageSource.gallery),
              borderRadius: BorderRadius.circular(kRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: AppColors.mutedForeground,
                    ),
                    SizedBox(height: 8),
                    Caption('PNG / JPG / WEBP, maksimal 8 MB per gambar'),
                  ],
                ),
              ),
            )
          else
            // Kotak sebanyak batasnya, supaya lebarnya tetap sama berapa pun
            // yang sudah dipilih; kotak kosong pertama untuk menambah.
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  for (var slot = 0; slot < widget.max; slot++) ...[
                    if (slot > 0) const SizedBox(width: 8),
                    Expanded(
                      child: slot < _shots.length
                          ? _tile(slot)
                          : slot == _shots.length
                          ? OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _pick(ImageSource.gallery),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _room == 0
                      ? null
                      : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeri'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _room == 0
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Kamera'),
                ),
              ),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Notice(
              color: AppColors.destructive,
              icon: Icons.warning_amber_rounded,
              child: Text(errors.join('\n\n')),
            ),
          ],
          const SizedBox(height: 12),
          Caption(
            _busy
                ? 'Jangan tutup lembar ini, permintaan sedang berjalan.'
                : 'Gambar hanya dibaca sekali dan tidak ikut tersimpan.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const Spacer(),
              BusyButton(
                busy: _busy,
                progress: _progress,
                icon: Icons.auto_awesome,
                label: _busy
                    ? 'Membaca gambar…'
                    : _shots.isNotEmpty && unread == 0
                    ? 'Pakai hasilnya'
                    : unread > 1
                    ? 'Baca $unread gambar'
                    : 'Baca dengan AI',
                onPressed: _shots.isEmpty ? null : _read,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nomor gambar — sama dengan nomor tab trade-nya di form.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
