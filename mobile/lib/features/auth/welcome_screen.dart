import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/session.dart';

const _slides = [
  (
    Icons.menu_book_outlined,
    'Jurnal yang mencatat semuanya',
    'Entry, stop loss, take profit, dan hasil setiap trade tersimpan rapi. '
        'Winrate dan RR dihitung otomatis.',
  ),
  (
    Icons.auto_awesome_outlined,
    'Isi dari screenshot',
    'Unggah layar posisi, AI membaca angkanya. Kamu tinggal periksa lalu simpan.',
  ),
  (
    Icons.shield_outlined,
    'Batas harian yang mengingatkan',
    'Atur maksimal loss dan target profit. Dashboard menandai hari yang melanggar.',
  ),
  (
    Icons.account_balance_wallet_outlined,
    'Dana dan laporan pajak',
    'Catat deposit dan withdrawal beserta buktinya. Laporan tahunan jadi PDF sekali ketuk.',
  ),
];

/// Perkenalan saat aplikasi pertama kali dibuka — sekali saja, sebelum layar
/// masuk. Yang sudah pernah masuk tidak melihatnya lagi (lihat `onboardedKey`).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _index = 0;

  bool get _last => _index == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(prefsProvider).setBool(onboardedKey, true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_last) {
      _finish();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_index + 1);
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 28,
                    height: 28,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Trade History',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                // Hilang di layar terakhir: tombol utamanya sudah "Mulai".
                if (!_last)
                  TextButton(onPressed: _finish, child: const Text('Lewati')),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) {
                final (icon, title, body) = _slides[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: .25),
                          ),
                        ),
                        child: Icon(icon, size: 30, color: AppColors.gold),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: Row(
              children: [
                // Posisi halaman, bukan hiasan: yang aktif memanjang.
                Semantics(
                  label: 'Halaman ${_index + 1} dari ${_slides.length}',
                  child: Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.gold
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(128, 48),
                  ),
                  child: Text(_last ? 'Mulai' : 'Lanjut'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
