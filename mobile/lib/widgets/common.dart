import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import 'skeleton.dart';

/// Jangkauan cache untuk halaman berisi (dashboard, aturan, analisa) — bukan
/// daftar tak berujung. Bawaan ListView (250 px) membuang bagian yang keluar
/// layar lalu membangunnya lagi saat kembali, jadi grafik dan markdown
/// dibangun ulang di tengah scroll dan frame-nya patah. Dengan jangkauan ini
/// semuanya tetap hidup; scroll tinggal menggeser lapisan yang sudah jadi.
const kWholePageCache = ScrollCacheExtent.pixels(5000);

/// Kaca tembus pandang seperti `.glass-card` di web, supaya cahaya latar
/// (`Backdrop`) ikut terlihat. Tanpa blur: di belakangnya hanya latar yang
/// sudah halus, jadi blur hanya memakan GPU tanpa beda yang terlihat.
final kPanelColor = AppColors.glass.withValues(alpha: .6);

ShapeBorder panelShape([Color? border]) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(kRadius),
  side: BorderSide(color: border ?? AppColors.border),
);

/// Kartu permukaan standar — padanan `.glass-card` di web.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  // Material, bukan DecoratedBox: ListTile & InkWell di dalam kartu melukis
  // efek sentuhnya di Material terdekat — di atas DecoratedBox berwarna,
  // efek itu tertutup.
  @override
  Widget build(BuildContext context) => Material(
    color: kPanelColor,
    clipBehavior: Clip.antiAlias,
    shape: panelShape(borderColor),
    child: Padding(
      padding: padding,
      child: title == null && trailing == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
    ),
  );
}

enum Tone { plain, good, bad, gold }

extension ToneColor on Tone {
  Color get color => switch (this) {
    Tone.plain => AppColors.foreground,
    Tone.good => AppColors.success,
    Tone.bad => AppColors.destructive,
    Tone.gold => AppColors.gold,
  };
}

/// Kartu angka: label kecil, nilai besar ber-font mono, keterangan di bawah.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.tone = Tone.plain,
  });

  final String label;
  final String value;
  final String? hint;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: .6,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: mono(size: 18, weight: FontWeight.w600, color: tone.color),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Ukuran huruf sistem 150% ke atas: baris yang biasanya berjajar ke samping
/// (nama + nominal) disusun ke bawah, seperti tumpukan Dynamic Type di iOS.
bool largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) >= 15;

/// Dua isian (atau dua nilai berlabel) berdampingan, ditumpuk bila separuh
/// lebar tidak muat untuk labelnya — huruf sistem yang besar, atau ponsel
/// sempit. Diputuskan dari lebar yang benar-benar tersedia, bukan jenis
/// perangkat: di tablet tetap berdampingan.
///
/// [minWidth] adalah lebar minimum satu sisi pada ukuran huruf normal. 128
/// menjaga form di ponsel 360 dp tetap berdampingan di ukuran normal dan
/// menumpuknya mulai 1,3×.
class FieldPair extends StatelessWidget {
  const FieldPair(this.first, this.second, {super.key, this.minWidth = 128});

  final Widget first;
  final Widget second;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final half = (constraints.maxWidth - 10) / 2;

      return half < MediaQuery.textScalerOf(context).scale(minWidth)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 14), second],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 10),
                Expanded(child: second),
              ],
            );
    },
  );
}

/// Kisi dua kolom untuk kartu angka (tiga di layar lebar); tinggi tiap baris
/// mengikuti isinya. Dengan huruf sistem yang besar kolomnya berkurang satu,
/// supaya angka di kartu ikut membesar alih-alih dikecilkan lagi agar muat.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          (constraints.maxWidth > 600 ? 3 : 2) - (largeText(context) ? 1 : 0);
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Label kecil abu-abu di atas isian atau angka.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      color: color ?? AppColors.mutedForeground,
      height: 1.35,
    ),
  );
}

/// Kotak peringatan berwarna — pelanggaran aturan, galat, catatan AI.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.child,
    this.color = AppColors.gold,
    this.icon,
  });

  final Widget child;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(kRadius - 2),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(fontSize: 12.5, color: color, height: 1.4),
      child: icon == null
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(child: child),
              ],
            ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: AppColors.mutedForeground),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedForeground),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// Galat pemuatan dengan tombol coba lagi.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: EmptyState(
      icon: Icons.cloud_off_outlined,
      message: error is ApiException ? '$error' : 'Terjadi kesalahan: $error',
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
            ),
    ),
  );
}

/// Memuat → isi → galat. Saat dimuat ulang (tarik untuk segarkan, atau data
/// lain baru disimpan), isi lama tetap tampil alih-alih berkedip jadi kerangka.
///
/// [loading] adalah kerangka milik layar itu sendiri ([SkeletonView]),
/// supaya bentuknya sama dengan isi yang akan datang.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: true,
    data: builder,
    loading: () => loading,
    error: (error, _) => ErrorView(error: error, onRetry: onRetry),
  );
}

/// Pesan singkat di bawah layar — padanan toast di web.
void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);

  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.destructiveFill : AppColors.accent,
        duration: Duration(milliseconds: error ? 5000 : 3000),
      ),
    );
}

/// Tombol utama dengan spinner saat sibuk.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

/// Pengganti `<select>`: kolomnya setinggi isian lain, menunya rapat di
/// bawah kolom (lihat `dropdownMenuTheme`). Mengetuk di mana pun di kolom
/// membuka menunya.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownMenu<T>(
    expandedInsets: EdgeInsets.zero,
    initialSelection: value,
    enabled: enabled,
    dropdownMenuEntries: [
      for (final (value, label) in options)
        DropdownMenuEntry(value: value, label: label),
    ],
    onSelected: (value) {
      if (value != null) onChanged(value);
    },
    // Panah biasa, bukan IconButton bawaan (48 px + jarak 4 px) yang
    // membuat kolom ini lebih tinggi dari isian di sebelahnya.
    decorationBuilder: (context, menu) => InputDecoration(
      labelText: label,
      errorText: errorText,
      suffixIcon: Icon(
        menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 40),
    ),
  );
}

/// Pilihan bersegmen ringkas — rentang periode, satuan, arah posisi.
class Segments<T> extends StatelessWidget {
  const Segments({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.colors,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Warna khusus per nilai saat terpilih (mis. buy hijau, sell merah).
  final Map<T, Color>? colors;

  // SegmentedButton, bukan kotak buatan sendiri: pembaca layar mengumumkan
  // pilihan yang aktif, targetnya 48 dp, dan ada umpan balik sentuh.
  // Lebar penuh: SegmentedButton membagi batas lebar yang ketat sama rata.
  @override
  Widget build(BuildContext context) {
    final tint = colors?[value];

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: [
          for (final (option, label) in options)
            ButtonSegment(
              value: option,
              // Mengecil bila perlu: dengan huruf sistem yang besar kata
              // seperti "Semua" terpotong di tengah kalau dibiarkan turun baris.
              label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
            ),
        ],
        selected: {value},
        onSelectionChanged: (picked) => onChanged(picked.first),
        style: tint == null
            ? null
            : SegmentedButton.styleFrom(
                selectedForegroundColor: onTint(tint),
                selectedBackgroundColor: tint.withValues(alpha: .18),
              ),
      ),
    );
  }
}

/// Konfirmasi hapus yang sengaja merepotkan: kode empat angka acak harus
/// diketik ulang, jadi tidak ada yang terhapus karena salah pencet.
/// Sama dengan `ConfirmDestroy.vue`.
Future<bool> confirmWithCode(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = 'Hapus',
}) async {
  final code = (1000 + Random().nextInt(9000)).toString();
  // Teks biasa, bukan TextEditingController: controller yang dibuang begitu
  // dialog ditutup masih dipakai kolomnya selama animasi keluar (keyboard
  // yang menutup membangunnya ulang) dan memicu galat.
  var typed = '';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        // Konten digulir bila keyboard + layar miring menyisakan sedikit
        // tinggi; tanpa ini kolom kodenya meluap keluar dialog.
        scrollable: true,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.destructive,
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Ketik ',
                children: [
                  TextSpan(
                    text: code,
                    style: mono(weight: FontWeight.w600, color: AppColors.gold),
                  ),
                  const TextSpan(text: ' untuk melanjutkan.'),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: mono(size: 16),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '0000',
              ),
              onChanged: (value) => setState(() => typed = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructiveFill,
              foregroundColor: AppColors.destructiveForeground,
            ),
            onPressed: typed == code
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}

/// Konfirmasi biasa untuk hal yang tidak menyentuh uang.
///
/// [destructive]: tombolnya merah, bukan emas — untuk hapus atau buang,
/// sama dengan konfirmasi yang memakai kode.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'Ya',
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null
            ? null
            : Text(
                message,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.destructiveFill,
                    foregroundColor: AppColors.destructiveForeground,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
