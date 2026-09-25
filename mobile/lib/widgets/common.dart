import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import 'skeleton.dart';

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
  //
  // Kaca tembus pandang seperti `.glass-card` di web, supaya cahaya latar
  // (`Backdrop`) ikut terlihat. Tanpa blur: di belakangnya hanya latar yang
  // sudah halus, jadi blur hanya memakan GPU tanpa beda yang terlihat.
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.glass.withValues(alpha: .6),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadius),
      side: BorderSide(color: borderColor ?? AppColors.border),
    ),
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
            fontSize: 10.5,
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

/// Kisi dua kolom untuk kartu angka; tinggi tiap baris mengikuti isinya.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 600 ? 3 : 2;
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
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: true,
    data: builder,
    loading: () => const SkeletonPage(),
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
        backgroundColor: error ? AppColors.destructive : AppColors.accent,
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

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(kRadius - 2),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        for (final (option, label) in options)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: option == value
                      ? (colors?[option]?.withValues(alpha: .18) ??
                            AppColors.accent)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadius - 5),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: option == value
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: option == value
                        ? (colors?[option] ?? AppColors.accentForeground)
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
  final typed = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
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
              controller: typed,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: mono(size: 16),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '0000',
              ),
              onChanged: (_) => setState(() {}),
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
              backgroundColor: AppColors.destructive,
              foregroundColor: AppColors.destructiveForeground,
            ),
            onPressed: typed.text == code
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  typed.dispose();

  return result ?? false;
}

/// Konfirmasi biasa untuk hal yang tidak menyentuh uang.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'Ya',
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
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
