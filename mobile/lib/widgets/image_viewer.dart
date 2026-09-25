import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/api_client.dart';
import 'common.dart';

/// Gambar layar penuh yang bisa dicubit-perbesar: tutup di kiri atas, unduh
/// ke galeri di kanan atas. [bytes] mengambil berkas aslinya saat diunduh.
Future<void> showImageViewer(
  BuildContext context, {
  required ImageProvider image,
  required Future<Uint8List> Function() bytes,
  required String name,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ImageViewer(image: image, bytes: bytes, name: name),
);

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.image,
    required this.bytes,
    required this.name,
  });

  final ImageProvider image;
  final Future<Uint8List> Function() bytes;
  final String name;

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
              child: Image(image: widget.image, fit: BoxFit.contain),
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
