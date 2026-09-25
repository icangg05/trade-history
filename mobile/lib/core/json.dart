/// Pembaca JSON yang toleran terhadap dua kebiasaan PHP:
///
/// * angka bulat keluar tanpa desimal (`1500` alih-alih `1500.0`), jadi semua
///   angka dibaca lewat `num`;
/// * array asosiatif yang kosong keluar sebagai `[]`, bukan `{}` — mis.
///   `violations` tanpa pelanggaran. `map()` menganggap keduanya peta kosong.
library;

typedef Json = Map<String, dynamic>;

double toDouble(Object? value) => toDoubleOrNull(value) ?? 0;

double? toDoubleOrNull(Object? value) => switch (value) {
  null => null,
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

int toInt(Object? value) => toIntOrNull(value) ?? 0;

int? toIntOrNull(Object? value) => switch (value) {
  null => null,
  num() => value.toInt(),
  String() => int.tryParse(value),
  _ => null,
};

String? toStringOrNull(Object? value) => value == null ? null : '$value';

Json map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<dynamic> list(Object? value) => value is List ? value : const [];

List<String> strings(Object? value) =>
    list(value).map((item) => '$item').toList();
