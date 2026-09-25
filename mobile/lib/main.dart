import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');

  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      // Galat jaringan ditampilkan dengan tombol "Coba lagi"; percobaan ulang
      // otomatis Riverpod hanya menunda pesannya sampai pengguna bingung.
      retry: (_, _) => null,
      child: const TradeHistoryApp(),
    ),
  );
}
