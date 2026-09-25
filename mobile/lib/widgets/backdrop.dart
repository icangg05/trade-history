import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Latar semua layar — padanan `.bg-ornaments` di web (lihat
/// `resources/css/app.css`): cahaya emas di kanan atas, sian di kiri atas,
/// ungu samar di bawah, dan kisi yang memudar dari atas.
///
/// Ukurannya dalam piksel logis yang sama dengan rem di web, jadi di layar
/// ponsel hasilnya sama dengan versi web yang dibuka di ponsel. Bedanya:
/// diam, tanpa animasi melayang, supaya tidak menguras baterai.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});

  final Widget child;

  // Selalu seukuran layar dan ditempel dari pojok kiri atas, berapa pun
  // tinggi halamannya: halaman tab (yang berhenti di atas nav bawah) dan
  // kerangka tab di belakang nav jadi menampilkan latar yang sama, menyambung
  // tanpa garis. Stack memotong sisanya.
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _Cached(
              MediaQuery.sizeOf(context),
              MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// Ornamennya dilukis sekali ke tekstur GPU, lalu tiap frame cukup
/// menempelkan tekstur itu. Impeller (renderer bawaan Android & iOS) tidak
/// menyimpan cache raster, jadi tanpa ini lima gradien selebar layar plus
/// lapisan kisi digambar ulang di setiap frame scroll, di setiap halaman.
class _Cached extends CustomPainter {
  const _Cached(this.screen, this.ratio);

  final Size screen;
  final double ratio;

  /// Satu untuk seluruh aplikasi: semua halaman memakai ukuran layar.
  /// Tekstur lama dilepas pemungut sampah, bukan `dispose()` — halaman lain
  /// yang ukurannya belum berganti (saat rotasi) mungkin masih memakainya.
  static ({Size size, double ratio, ui.Image image})? _cache;

  static ui.Image _imageFor(Size size, double ratio) {
    final cached = _cache;

    if (cached != null && cached.size == size && cached.ratio == ratio) {
      return cached.image;
    }

    final recorder = ui.PictureRecorder();
    const _Ornaments().paint(Canvas(recorder)..scale(ratio), size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * ratio).ceil(),
      (size.height * ratio).ceil(),
    );
    picture.dispose();

    _cache = (size: size, ratio: ratio, image: image);

    return image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (screen.isEmpty) return;

    final image = _imageFor(screen, ratio);

    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & screen,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_Cached oldDelegate) =>
      oldDelegate.screen != screen || oldDelegate.ratio != ratio;
}

class _Ornaments extends CustomPainter {
  const _Ornaments();

  static const _violet = Color(0xFF7847EB); // hsl(258 80% 60%)

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Dasar: hsl(222 32% 7%) → hsl(222 30% 5%).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [
          Color(0xFF0C1018),
          Color(0xFF090B11),
        ]),
    );

    // radial-gradient(<rx> <ry> at <pusat>, warna, transparent <ujung>%)
    _glow(
      canvas,
      Offset(w, -.08 * h),
      800 * .52,
      672 * .52,
      AppColors.gold,
      .14,
    );
    _glow(
      canvas,
      Offset(-.08 * w, .04 * h),
      768 * .52,
      704 * .52,
      AppColors.cyan,
      .12,
    );
    _glow(canvas, Offset(.5 * w, 1.2 * h), 704 * .6, 640 * .6, _violet, .10);

    // .blob-a dan .blob-b: lingkaran buram berwarna di dua sudut.
    _glow(canvas, Offset(w - 112, 112), 262, 262, AppColors.gold, .12);
    _glow(canvas, Offset(96, h - 64), 240, 240, AppColors.cyan, .14);

    _grid(canvas, size);
  }

  /// Kisi 42 px, memudar ke bawah lewat topeng elips 80% × 60% dari tengah atas.
  void _grid(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = AppColors.cyan.withValues(alpha: .05)
      ..strokeWidth = 1;

    canvas.saveLayer(Offset.zero & size, Paint());

    for (var x = 0.0; x <= w; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), line);
    }
    for (var y = 0.0; y <= h; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }

    // Topeng: hanya garis di dalam elips yang tersisa (dstIn).
    final rx = .8 * w;
    final squash = (.6 * h) / rx;

    canvas
      ..save()
      ..translate(w / 2, 0)
      ..scale(1, squash)
      ..drawRect(
        Rect.fromLTRB(-w / 2, 0, w / 2, h / squash),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            const [Colors.black, Colors.black, Colors.transparent],
            const [0, .3, .75],
          ),
      )
      ..restore()
      ..restore();
  }

  /// Cahaya elips yang memudar ke transparan tepat di tepinya.
  static void _glow(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    Color color,
    double alpha,
  ) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, ry / rx)
      ..drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, rx, [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_Ornaments oldDelegate) => false;
}
