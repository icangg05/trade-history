import 'package:flutter/material.dart';

/// Token warna dari `resources/css/app.css` versi web, dikonversi dari HSL.
/// Tema gelap saja — sama seperti web, tidak ada mode terang.
abstract final class AppColors {
  static const background = Color(0xFF0B0D14);
  static const foreground = Color(0xFFECF0F3);
  static const card = Color(0xFF151A23);
  static const popover = Color(0xFF11151D);
  static const glass = Color(0xFF191E2A);

  /// Emas = aksi utama, highlight, brand. Bukan untuk profit.
  static const gold = Color(0xFFFBBD23);
  static const goldForeground = Color(0xFF221907);

  static const secondary = Color(0xFF212631);
  static const muted = Color(0xFF1F242D);
  static const mutedForeground = Color(0xFF8F9BAE);
  static const accent = Color(0xFF242B38);
  static const accentForeground = Color(0xFFFBC641);

  /// Data sekunder: deposit/withdrawal di grafik, penanda BE / SL+.
  static const cyan = Color(0xFF28DEF6);

  /// Rugi, hari merah, pelanggaran aturan.
  static const destructive = Color(0xFFE23C3C);
  static const destructiveForeground = Color(0xFFF8FAFC);

  /// Untung, hari hijau.
  static const success = Color(0xFF28C37A);
  static const successForeground = Color(0xFF0E121B);

  static const border = Color(0xFF2B3546);
  static const input = Color(0xFF2F3A4C);
}

const kRadius = 12.0;

/// Chip pilihan (strategi, filter, sesi). Tinggi chip Material ditentukan
/// batas minimumnya, bukan padding — batas itu hanya turun lewat densitas.
/// Pasangannya di tiap chip: `materialTapTargetSize: shrinkWrap`, tanpa itu
/// setiap chip tetap memesan tinggi 48 px dan barisnya renggang.
const kDenseChip = VisualDensity(
  horizontal: -2,
  vertical: VisualDensity.minimumDensity,
);

const kSans = 'IBMPlexSans';

/// Semua angka uang, harga, lot, dan P/L memakai Plex Mono berangka tabel
/// supaya kolomnya rata.
const kMono = 'IBMPlexMono';

TextStyle mono({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => TextStyle(
  fontFamily: kMono,
  fontSize: size,
  fontWeight: weight,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.gold,
    onPrimary: AppColors.goldForeground,
    secondary: AppColors.secondary,
    onSecondary: AppColors.foreground,
    tertiary: AppColors.cyan,
    onTertiary: AppColors.background,
    error: AppColors.destructive,
    onError: AppColors.destructiveForeground,
    surface: AppColors.background,
    onSurface: AppColors.foreground,
    onSurfaceVariant: AppColors.mutedForeground,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.popover,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.glass,
    surfaceContainerHighest: AppColors.accent,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    inverseSurface: AppColors.foreground,
    onInverseSurface: AppColors.background,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kSans,
    // Transparan: latarnya dilukis `Backdrop` di bawah setiap halaman.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.background,
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
  );

  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(kRadius - 2),
    borderSide: const BorderSide(color: AppColors.input),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kSans,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      hintStyle: const TextStyle(color: AppColors.mutedForeground),
      labelStyle: const TextStyle(color: AppColors.mutedForeground),
      floatingLabelStyle: const TextStyle(color: AppColors.gold),
      helperMaxLines: 4,
      errorMaxLines: 4,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      errorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.destructive),
      ),
      focusedErrorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.destructive),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.goldForeground,
        textStyle: const TextStyle(
          fontFamily: kSans,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius - 2),
        ),
        minimumSize: const Size(0, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.foreground,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius - 2),
        ),
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: AppColors.mutedForeground,
        selectedForegroundColor: AppColors.accentForeground,
        selectedBackgroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.border),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontFamily: kSans, fontSize: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.background,
      selectedColor: AppColors.gold.withValues(alpha: .12),
      checkmarkColor: AppColors.gold,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
        fontFamily: kSans,
        fontSize: 12,
        color: AppColors.foreground,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // Rapat: daftar strategi bisa puluhan pilihan (lihat kDenseChip).
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.gold.withValues(alpha: .15),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kSans,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.mutedForeground,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.mutedForeground,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.popover,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.popover,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.accent,
      contentTextStyle: const TextStyle(
        fontFamily: kSans,
        color: AppColors.foreground,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius - 2),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.mutedForeground,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.goldForeground,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.popover,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius - 2),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
