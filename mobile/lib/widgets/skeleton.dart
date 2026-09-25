import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

/// Kilau yang menyapu kerangka selama data dimuat — pengganti spinner, jadi
/// bentuk halaman sudah terlihat sebelum isinya datang. Satu [Shimmer] cukup
/// untuk satu kerangka utuh; tulang-tulangnya tidak perlu beranimasi sendiri.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pengguna yang mematikan animasi di pengaturan ponsel cukup melihat
    // kerangkanya diam.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) =>
            LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: .07),
                Colors.transparent,
              ],
              stops: const [.3, .5, .7],
            ).createShader(
              // Menyapu dari luar kiri ke luar kanan.
              Rect.fromLTWH(
                (_controller.value * 2 - 1) * bounds.width,
                0,
                bounds.width,
                bounds.height,
              ),
            ),
        child: child,
      ),
    );
  }
}

/// Satu balok abu-abu di kerangka: pengganti teks, angka, atau gambar.
class Bone extends StatelessWidget {
  const Bone({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.secondary,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Baris-baris teks: paragraf analisa, detail trade.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 4});

  final int lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < lines; i++) ...[
        // Baris terakhir lebih pendek, seperti ujung paragraf.
        FractionallySizedBox(
          widthFactor: i == lines - 1 ? .55 : (i.isEven ? 1 : .85),
          child: const Bone(),
        ),
        if (i < lines - 1) const SizedBox(height: 10),
      ],
    ],
  );
}

/// Satu kartu baris daftar: gambar kecil, dua baris teks, angka di kanan.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => const Panel(
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Bone(width: 44, height: 44),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(widthFactor: .5, child: Bone()),
              SizedBox(height: 8),
              FractionallySizedBox(widthFactor: .8, child: Bone(height: 9)),
            ],
          ),
        ),
        SizedBox(width: 12),
        Bone(width: 56),
      ],
    ),
  );
}

/// Kerangka halaman bawaan: kartu angka lalu baris daftar — bentuk yang
/// dipakai hampir semua layar (dashboard, trade, dana, analisa).
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        StatGrid(
          children: [
            for (var i = 0; i < 4; i++)
              const Panel(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(width: 70, height: 9),
                    SizedBox(height: 12),
                    Bone(width: 110, height: 18),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows; i++) ...[
          const SkeletonRow(),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}
