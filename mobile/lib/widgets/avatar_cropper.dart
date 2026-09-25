import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/theme.dart';
import 'common.dart';

/// Sisi hasil potongan. Foto profil terbesar di aplikasi bergaris tengah
/// 56 px; di layar 3–4× itu ±220 px, jadi 512 px masih tajam.
const _outputSide = 512.0;

/// Potong foto profil sebelum diunggah: geser dan cubit fotonya sampai pas di
/// lingkaran. Yang terlihat di dalam bingkai itulah hasilnya — PNG persegi
/// 512 px. Null kalau dibatalkan.
Future<Uint8List?> cropAvatar(BuildContext context, Uint8List bytes) async {
  final image = await decodeImageFromList(bytes);

  if (!context.mounted) {
    image.dispose();
    return null;
  }

  return Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AvatarCropper(image: image),
    ),
  );
}

/// Pemilik [image]: dilepas saat layar ini benar-benar hilang, bukan saat
/// hasilnya dikembalikan — animasi keluarnya masih melukis foto itu.
class AvatarCropper extends StatefulWidget {
  const AvatarCropper({super.key, required this.image});

  final ui.Image image;

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  final _frame = GlobalKey();
  TransformationController? _transform;
  bool _busy = false;

  @override
  void dispose() {
    _transform?.dispose();
    widget.image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    final frame =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final shot = await frame.toImage(
      pixelRatio: _outputSide / frame.size.width,
    );
    final png = await shot.toByteData(format: ui.ImageByteFormat.png);
    shot.dispose();

    if (mounted) Navigator.pop(context, png?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // Warna penuh, bukan transparan seperti halaman lain: layar ini tidak
    // lewat router, jadi tidak punya `Backdrop` di belakangnya.
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Atur foto'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan'),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final image = widget.image;
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight - 60) - 48;

        // Sisi pendek foto = sisi bingkai: bingkai selalu tertutup penuh
        // (tidak bisa diperkecil melewati itu), dan sisi panjangnya bisa
        // digeser. Awalnya di tengah.
        final fit = side / math.min(image.width, image.height);
        final width = image.width * fit;
        final height = image.height * fit;

        _transform ??= TransformationController(
          Matrix4.translationValues(
            -(width - side) / 2,
            -(height - side) / 2,
            0,
          ),
        );

        return Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        key: _frame,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            maxScale: 5,
                            child: RawImage(
                              image: image,
                              width: width,
                              height: height,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                      // Di luar tangkapan: hanya panduan, tidak ikut diunggah.
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CircleGuide()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Caption('Geser dan cubit untuk mengatur posisi foto.'),
            ),
          ],
        );
      },
    ),
  );
}

/// Sudut di luar lingkaran digelapkan: bagian itu terpotong saat foto
/// profil ditampilkan bulat.
class _CircleGuide extends CustomPainter {
  const _CircleGuide();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;

    canvas
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(frame)
          ..addOval(frame),
        Paint()..color = AppColors.background.withValues(alpha: .6),
      )
      ..drawOval(
        frame.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.foreground.withValues(alpha: .6),
      );
  }

  @override
  bool shouldRepaint(_CircleGuide oldDelegate) => false;
}
