import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Daftar strategi bawaan — sama dengan `SetupPicker.vue`.
const kSetups = [
  'Supply Demand',
  'Support Resisten',
  'Fibonacci',
  'Order Block',
  'FVG',
  'Parallel Channel',
  'Break of Structure',
  'CHoCH',
  'Liquidity Sweep',
  'Trendline',
  'Moving Average',
  'Breakout',
  'Pullback',
  'Pola Candlestick',
  'Double Top',
  'Double Bottom',
  'Head & Shoulders',
  'Inv. Head & Shoulders',
  'Triple Top',
  'Triple Bottom',
  'Ascending Triangle',
  'Descending Triangle',
  'Symmetrical Triangle',
  'Rising Wedge',
  'Falling Wedge',
  'Flag',
  'Pennant',
  'Cup & Handle',
  'Rectangle / Range',
];

List<String> splitSetup(String? value) => (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

/// Satu trade sering memakai beberapa strategi, jadi `setup` disimpan sebagai
/// daftar dipisah koma. Nilai di luar daftar bawaan (hasil baca AI, trade lama)
/// tetap muncul sebagai pilihan supaya tidak hilang saat diedit.
class SetupPicker extends StatelessWidget {
  const SetupPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = splitSetup(value);
    final options = {...kSetups, ...selected}.toList();

    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              // Tanpa centang: warna emas sudah menandai pilihan, dan centang
              // melebarkan chip sampai barisnya patah lebih sering.
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: kDenseChip,
              labelStyle: TextStyle(
                fontSize: 11.5,
                color: selected.contains(option)
                    ? AppColors.gold
                    : AppColors.mutedForeground,
              ),
              side: BorderSide(
                color: selected.contains(option)
                    ? AppColors.gold.withValues(alpha: .6)
                    : AppColors.border,
              ),
              onSelected: !enabled
                  ? null
                  : (on) => onChanged(
                      (on
                              ? [...selected, option]
                              : selected.where((item) => item != option))
                          .join(', '),
                    ),
            ),
        ],
      ),
    );
  }
}
