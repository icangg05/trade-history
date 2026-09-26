import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart' as sk;

import '../core/theme.dart';
import 'common.dart';

/// Kilau yang menyapu kerangka selama data dimuat — pengganti spinner, jadi
/// bentuk halaman sudah terlihat sebelum isinya datang. Mesinnya paket
/// skeletonizer: di dalam zona ini hanya [Bone] yang dilukis sebagai kerangka,
/// kartu di sekitarnya tampil apa adanya.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  // Pembaca layar mendengar "Memuat…", bukan diam: tulang-tulangnya tidak
  // punya teks. Semua kerangka lewat widget ini, jadi cukup di sini.
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat…',
    liveRegion: true,
    excludeSemantics: true,
    child: sk.Skeletonizer.zone(
      // Pengguna yang mematikan animasi di pengaturan ponsel cukup melihat
      // kerangkanya diam.
      effect: MediaQuery.disableAnimationsOf(context)
          ? const sk.SolidColorEffect(color: AppColors.secondary)
          : sk.ShimmerEffect(
              baseColor: AppColors.secondary,
              highlightColor: Color.alphaBlend(
                Colors.white.withValues(alpha: .07),
                AppColors.secondary,
              ),
              duration: const Duration(milliseconds: 1400),
            ),
      child: child,
    ),
  );
}

/// Satu balok di kerangka: pengganti teks, angka, atau gambar. Tulang
/// skeletonizer dengan ukuran bawaan, supaya kerangka tiap layar cukup
/// menyebut yang berbeda.
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
  Widget build(BuildContext context) =>
      sk.Bone(width: width, height: height, uniRadius: radius);
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

/// Kartu baris dana: bukti kecil, dua baris teks, nominal di kanan — sebanyak
/// [count], berjarak seperti daftar aslinya.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        const Panel(
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
                    FractionallySizedBox(
                      widthFactor: .8,
                      child: Bone(height: 9),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Bone(width: 56),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Baris riwayat trade: badge arah, simbol + waktu, P/L di kanan. Tanpa
/// kartu — dipasang di dalam kartu riwayat atau "Trade terakhir".
class SkeletonTradeRows extends StatelessWidget {
  const SkeletonTradeRows({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const Divider(indent: 12, endIndent: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Bone(width: 40, height: 16),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(width: 72),
                    SizedBox(height: 6),
                    Bone(width: 110, height: 9),
                  ],
                ),
              ),
              Bone(width: 64),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Kisi kartu angka, sebanyak kartu di layar aslinya.
class SkeletonStats extends StatelessWidget {
  const SkeletonStats({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => StatGrid(
    children: [
      for (var i = 0; i < count; i++)
        const Panel(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone(width: 70, height: 9),
              SizedBox(height: 10),
              Bone(width: 110, height: 18),
              SizedBox(height: 6),
              Bone(width: 90, height: 9),
            ],
          ),
        ),
    ],
  );
}

/// Kotak isian, pilihan bersegmen, atau tombol — setinggi aslinya.
class SkeletonField extends StatelessWidget {
  const SkeletonField({super.key, this.width = double.infinity});

  final double width;

  @override
  Widget build(BuildContext context) =>
      Bone(width: width, height: 44, radius: kRadius - 2);
}

/// Deretan isian form: profil, aturan, laporan, form trade.
class SkeletonFields extends StatelessWidget {
  const SkeletonFields({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        const SkeletonField(),
      ],
    ],
  );
}

/// Kartu berjudul ([Panel] dengan `title`): judul pendek lalu isinya.
class SkeletonPanel extends StatelessWidget {
  const SkeletonPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Bone(width: 120, height: 13),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

/// Kerangka satu layar: bagian-bagiannya disusun seperti isi layar itu
/// (tiap layar merakitnya sendiri), disapu satu [Shimmer]. Tidak digulir —
/// isinya belum ada.
class SkeletonView extends StatelessWidget {
  const SkeletonView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: children.length,
      // Rata kiri, bukan diregangkan: tulang pendek (keterangan, judul)
      // tetap pendek seperti teks aslinya.
      itemBuilder: (_, index) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: children[index],
      ),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
    ),
  );
}
