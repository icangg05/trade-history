import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/backdrop.dart';

/// Tab bar bawah, sama urutannya dengan tab bar mobile di web: Dashboard,
/// Kalender, Trade di tengah, Dana, lalu Lainnya (aturan, analisa, laporan…).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Dashboard'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Kalender'),
    (Icons.format_list_numbered, Icons.format_list_numbered_rtl, 'Trade'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Dana',
    ),
    (Icons.more_horiz, Icons.more_horiz, 'Lainnya'),
  ];

  /// Pulau mengambang seperti tab bar web. Tanpa blur: yang ada di
  /// belakangnya hanya latar, bukan isi halaman yang sedang di-scroll.
  static final _island = ShapeDecoration(
    color: AppColors.popover.withValues(alpha: .92),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: AppColors.foreground.withValues(alpha: .07)),
    ),
    shadows: const [
      BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  List<Widget> _items() => [
    for (final (index, (icon, active, label)) in _tabs.indexed)
      _Tab(
        icon: icon,
        activeIcon: active,
        label: label,
        selected: index == shell.currentIndex,
        // Mengetuk tab yang sedang aktif kembali ke layar teratasnya.
        onTap: () =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
  ];

  // Latar di sini juga: nav mengambang, jadi celah di sekelilingnya harus
  // menampilkan latar yang sama dengan halaman di atasnya.
  //
  // Layar lebar (tablet, ponsel yang dimiringkan): pulau yang sama berdiri
  // di kiri sebagai rail. Di ponsel miring, tab bar bawah menghabiskan
  // hampir separuh tinggi layar yang sudah pendek.
  @override
  Widget build(BuildContext context) {
    final rail = MediaQuery.sizeOf(context).width >= 600;

    return Backdrop(
      child: Scaffold(
        body: rail
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    minimum: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    // Bisa digulir: saat keyboard terbuka di ponsel miring,
                    // tinggi yang tersisa lebih pendek dari lima tab.
                    child: Center(
                      child: SingleChildScrollView(
                        child: DecoratedBox(
                          decoration: _island,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: SizedBox(
                              width: 68,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _items(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: shell),
                ],
              )
            : shell,
        bottomNavigationBar: rail
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: DecoratedBox(
                  decoration: _island,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        for (final item in _items()) Expanded(child: item),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Satu tab: ikon di kotak membulat yang menyala emas saat aktif — sama
/// dengan `bg-gold/15 ring-1 ring-gold/25` di web. Hanya perubahan pilihan
/// yang dianimasikan, dan tidak sama sekali kalau animasi dimatikan.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.mutedForeground;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    // Label tab berhenti membesar di 120% — seperti tab bar iOS — supaya lima
    // label tetap seukuran satu sama lain; pembaca layar tetap membacakannya.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 34,
                  decoration: ShapeDecoration(
                    color: selected
                        ? AppColors.gold.withValues(alpha: .15)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? AppColors.gold.withValues(alpha: .25)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 21,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                // Mengecil bila perlu, bukan terpotong jadi "Dashboar" saat
                // huruf sistem dibesarkan — lebar tab tidak ikut membesar.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
