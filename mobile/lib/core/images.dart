import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Gambar dari galeri/kamera → JPEG yang siap diunggah. Screenshot ponsel
/// biasanya PNG 1–3 MB; sebagai JPEG ukurannya tinggal sepersekiannya.
///
/// [side] adalah batas sisi *pendek*: foto kamera 4000×3000 dengan side 1440
/// jadi 1920×1440, sedangkan screenshot 1080×2400 tidak diperkecil — hanya
/// dikodekan ulang, jadi tulisan di bukti transfer tetap terbaca. EXIF
/// (termasuk lokasi GPS) ikut dibuang.
Future<Uint8List> compressImage(
  XFile file, {
  int side = 1440,
  int quality = 80,
}) async {
  final original = await file.readAsBytes();

  try {
    final compressed = await FlutterImageCompress.compressWithList(
      original,
      minWidth: side,
      minHeight: side,
      quality: quality,
    );

    // Gambar yang sudah kecil bisa malah membesar setelah dikodekan ulang.
    return compressed.isNotEmpty && compressed.length < original.length
        ? compressed
        : original;
  } on Object catch (error) {
    // Format yang tidak dikenali plugin (mis. HEIC di Android lama): kirim
    // aslinya dan biarkan server yang menilai.
    debugPrint('compressImage: $error');
    return original;
  }
}
