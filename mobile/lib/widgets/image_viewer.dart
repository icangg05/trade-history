import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/api_client.dart';
import 'common.dart';

/// Gambar layar penuh yang bisa dicubit-perbesar: tutup di kiri atas, unduh
/// ke galeri di kanan atas. [bytes] mengambil berkas aslinya saat diunduh.
/// [preview] (versi kecilnya) tampil lebih dulu selama aslinya diunduh.
Future<void> showImageViewer(
  BuildContext context, {
  required ImageProvider image,
  required Future<Uint8List> Function() bytes,
  required String name,
  ImageProvider? preview,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ImageViewer(image: image, bytes: bytes, name: name, preview: preview),
);

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.image,
    required this.bytes,
    required this.name,
    this.preview,
  });

  final ImageProvider image;
  final Future<Uint8List> Function() bytes;
  final String name;
  final ImageProvider? preview;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await saveToGallery(context, widget.bytes, widget.name);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    // Bulatan gelap di belakang ikon: tetap terbaca di atas gambar yang putih.
    final style = IconButton.styleFrom(
      backgroundColor: Colors.black54,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black54,
      disabledForegroundColor: Colors.white,
      side: const BorderSide(color: Colors.white24),
    );

    // Versi kecilnya dulu (kalau ada), dengan kemajuan unduhan aslinya di atas.
    Widget loading([double? value]) => Stack(
      fit: StackFit.expand,
      children: [
        if (widget.preview != null)
          Image(image: widget.preview!, fit: BoxFit.contain),
        _Loading(value),
      ],
    );

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      // Scaffold sendiri: pesan "disimpan ke galeri" tampil di atas gambar,
      // bukan di halaman yang tertutup dialog ini.
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Image(
                image: widget.image,
                fit: BoxFit.contain,
                // Sebelum byte pertama tiba dan selama didekode belum ada
                // bingkai — tanpa ini layarnya hitam kosong beberapa detik.
                frameBuilder: (_, child, frame, sync) =>
                    frame == null && !sync ? loading() : child,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : loading(
                        progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                      ),
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Gambar gagal dimuat.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
            // Positioned, bukan anak biasa: StackFit.expand meregangkan anak
            // biasa setinggi layar, dan tombolnya jadi ada di tengah.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filled(
                        style: style,
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      // Sekali ketuk sampai selesai: selama mengunduh
                      // tombolnya jadi putaran dan tidak bisa diketuk lagi.
                      IconButton.filled(
                        style: style,
                        tooltip: _saving ? 'Mengunduh…' : 'Unduh',
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Putaran + persen selama gambar penuh diunduh. [value] null = belum tahu
/// ukurannya (atau sedang didekode), jadi putarannya tanpa angka.
class _Loading extends StatelessWidget {
  const _Loading([this.value]);

  final double? value;

  @override
  Widget build(BuildContext context) => Center(
    // Latar gelap: tetap terbaca di atas pratinjau yang putih.
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: value, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            value == null
                ? 'Memuat gambar…'
                : 'Memuat gambar… ${(value! * 100).round()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

/// Simpan gambar ke galeri ponsel, di album "Trade History".
Future<void> saveToGallery(
  BuildContext context,
  Future<Uint8List> Function() bytes,
  String name,
) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      if (context.mounted) {
        showMessage(
          context,
          'Izin galeri ditolak. Izinkan dari pengaturan aplikasi.',
          error: true,
        );
      }
      return;
    }

    await Gal.putImageBytes(await bytes(), album: 'Trade History', name: name);

    if (context.mounted) showMessage(context, 'Gambar disimpan ke galeri.');
  } on ApiException catch (error) {
    if (context.mounted) showMessage(context, error.message, error: true);
  } on GalException catch (error) {
    if (context.mounted) {
      showMessage(context, switch (error.type) {
        GalExceptionType.accessDenied => 'Izin galeri ditolak.',
        GalExceptionType.notEnoughSpace => 'Penyimpanan ponsel penuh.',
        GalExceptionType.notSupportedFormat => 'Format gambar tidak didukung.',
        GalExceptionType.unexpected => 'Gagal menyimpan ke galeri.',
      }, error: true);
    }
  }
}
