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

Future<AiImport?> showAiImport(
  BuildContext context,
  int account,
) => showModalBottomSheet<AiImport>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  // Selama permintaan berjalan lembar ini dikunci: menutupnya di tengah jalan
  // hanya membuang permintaan yang kuotanya sudah terlanjur terpakai.
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _AiImportSheet(account: account),
);

class _AiImportSheet extends ConsumerStatefulWidget {
  const _AiImportSheet({required this.account});

  final int account;

  @override
  ConsumerState<_AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends ConsumerState<_AiImportSheet> {
  XFile? _file;
  Uint8List? _bytes;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2560,
        imageQuality: 92,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _file = file;
        _bytes = bytes;
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
    });

    try {
      final result = await ref
          .read(journalProvider)
          .extract(widget.account, _file!);

      if (mounted) Navigator.pop(context, (result: result, image: _bytes!));
    } on ApiException catch (error) {
      // Bukan screenshot trading, atau datanya tidak lengkap: lembar tetap
      // terbuka dengan alasannya, tidak ada field yang diisi setengah-setengah.
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
        const Caption(
          'Unggah layar posisi atau riwayat order yang memuat entry, SL, dan TP. '
          'Hasilnya mengisi form, periksa dulu sebelum disimpan.',
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: _bytes == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: AppColors.mutedForeground,
                    ),
                    SizedBox(height: 8),
                    Caption('PNG / JPG / WEBP, maksimal 8 MB'),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _bytes!,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeri'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Kamera'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Notice(
            color: AppColors.destructive,
            icon: Icons.warning_amber_rounded,
            child: Text(_error!),
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
              icon: Icons.auto_awesome,
              label: _busy ? 'Membaca gambar…' : 'Baca dengan AI',
              onPressed: _file == null ? null : _read,
            ),
          ],
        ),
      ],
    ),
  );
}
