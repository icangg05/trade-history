import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/backdrop.dart';

/// Tab terakhir sebelum Lainnya dibuka dari header: tujuan tombol kembali
/// di sana. Lainnya tetap satu cabang shell (subhalamannya tetap memakai
/// tab bar), hanya tidak lagi punya tab sendiri.
var _lastTab = 0;

void openMore(BuildContext context) => context.go('/more');

void leaveMore(BuildContext context) =>
    StatefulNavigationShell.of(context).goBranch(_lastTab);

/// Tab bar bawah: Dashboard, Kalender, tombol + untuk trade baru di tengah,
/// Trade, Dana. Lainnya (aturan, analisa, laporan…) dibuka dari header.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Urutan sama dengan cabang di `app.dart`; cabang kelima (Lainnya) tidak
  /// punya tab.
  static const _tabs = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Dashboard'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Kalender'),
    (Icons.format_list_numbered, Icons.format_list_numbered_rtl, 'Trade'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Dana',
    ),
  ];

  static const _border = BorderSide(color: Color(0x12ECF0F3));
  static const _shadows = [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Pulau mengambang seperti tab bar web. Tanpa blur: yang ada di
  /// belakangnya hanya latar, bukan isi halaman yang sedang di-scroll.
  static final _island = ShapeDecoration(
    color: AppColors.popover.withValues(alpha: .92),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: _border,
    ),
    shadows: _shadows,
  );

  /// Pulau yang sama dengan lekukan tempat tombol + duduk.
  static final _cradled = ShapeDecoration(
    color: AppColors.popover.withValues(alpha: .92),
    shape: const _Cradle(_border),
    shadows: _shadows,
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
    final items = _items();

    if (shell.currentIndex < _tabs.length) _lastTab = shell.currentIndex;

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
                                children: [
                                  ...items.take(2),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: _AddTrade(size: 48),
                                  ),
                                  ...items.skip(2),
                                ],
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
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: _Cradle.rise),
                      child: DecoratedBox(
                        decoration: _cradled,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              for (final item in items.take(2))
                                Expanded(child: item),
                              const SizedBox(width: _Cradle.slot),
                              for (final item in items.skip(2))
                                Expanded(child: item),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const _AddTrade(size: _Cradle.button),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Pulau membulat dengan lekukan melingkar di tengah atas — tombol + duduk
/// di dalamnya, menyembul [rise] px di atas pulau.
class _Cradle extends ShapeBorder {
  const _Cradle(this.side);

  final BorderSide side;

  static const button = 56.0;
  static const rise = 16.0;
  static const _gap = 6.0;

  /// Lebar kolom kosong di antara dua pasang tab.
  static const slot = button + _gap * 2 + 8;

  Rect _notch(Rect rect) => Rect.fromCircle(
    center: Offset(rect.center.dx, rect.top + button / 2 - rise),
    radius: button / 2 + _gap,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path.combine(
    PathOperation.intersect,
    const CircularNotchedRectangle().getOuterPath(rect, _notch(rect)),
    Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(28))),
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      canvas.drawPath(getOuterPath(rect), side.toPaint());
}

/// Tombol + emas untuk trade baru. Menciut sedikit saat ditekan (umpan
/// balik sentuh), tidak sama sekali kalau animasi dimatikan.
class _AddTrade extends StatefulWidget {
  const _AddTrade({required this.size});

  final double size;

  @override
  State<_AddTrade> createState() => _AddTradeState();
}

class _AddTradeState extends State<_AddTrade> {
  bool _down = false;

  void _press(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: 'Tambah trade',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Tambah trade',
        child: GestureDetector(
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/trade/new');
          },
          child: AnimatedScale(
            scale: _down && !still ? .92 : 1,
            duration: still ? Duration.zero : const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                // Emas sedikit lebih terang di atas: terasa timbul tanpa
                // pendar neon.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFDD15C), AppColors.gold],
                ),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0x33FFFFFF)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40FBBD23),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                size: widget.size * .52,
                color: AppColors.goldForeground,
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
