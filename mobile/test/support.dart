import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trade_history/app.dart';
import 'package:trade_history/data/session.dart';

/// Jawaban server yang direkam dari API sungguhan (`php artisan serve` +
/// DemoSeeder) — lihat `test/fixtures/`.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

typedef Handler = Object Function(RequestOptions request);

/// Jawaban dengan status selain 200.
class Reply {
  const Reply(this.status, this.body);

  final int status;
  final Object body;
}

/// Server palsu untuk Dio: rute dicocokkan sebagai regex terhadap
/// `METHOD path` (tanpa awalan /api/v1/ dan tanpa query).
class FakeServer implements HttpClientAdapter {
  FakeServer(this.routes);

  final Map<String, Handler> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final key =
        '${options.method} ${options.uri.path.replaceFirst('/api/v1/', '')}';
    final handler = routes.entries
        .where((route) => RegExp('^${route.key}\$').hasMatch(key))
        .firstOrNull
        ?.value;
    final result = handler == null
        ? const Reply(404, {'message': 'Not Found'})
        : handler(options);
    final reply = result is Reply ? result : Reply(200, result);

    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final defaultRoutes = <String, Handler>{
  'GET auth/options': (_) => fixture('options'),
  'POST auth/login': (_) => {
    'token': '1|token-uji',
    'user': {'id': 1, 'name': 'Trader Demo', 'email': 'demo@contoh.com'},
  },
  'POST auth/logout': (_) => {'message': 'Kamu sudah keluar.'},
  'GET me': (_) => fixture('me'),
  'GET profile': (_) => fixture('profile'),
  'GET accounts': (_) => fixture('accounts'),
  'GET reports': (_) => fixture('reports'),
  'GET accounts/1/dashboard': (_) => fixture('dashboard'),
  'GET accounts/1/calendar': (_) => fixture('calendar'),
  'GET accounts/1/trades': (_) => fixture('trades'),
  'GET accounts/1/trades/create': (_) => fixture('trade_create'),
  'GET accounts/1/trades/[A-Za-z0-9]+': (_) => fixture('trade_edit'),
  'GET accounts/1/transactions': (_) => fixture('transactions'),
  'GET accounts/1/rules': (_) => fixture('rules'),
  'GET accounts/1/analysis': (_) => fixture('analysis'),
};

Future<void> setUpFormatting() async {
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');
}

/// Jalankan aplikasi utuh di ukuran layar ponsel (360 × 780).
Future<FakeServer> pumpApp(
  WidgetTester tester, {
  bool loggedIn = true,
  bool onboarded = true,
  Map<String, Handler> routes = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData({
        'server': 'https://trade.contoh.test',
        'account_id': 1,
        if (onboarded) 'onboarded': true,
      });
  FlutterSecureStorage.setMockInitialValues(
    loggedIn ? {'token': '1|token-uji'} : {},
  );

  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  final server = FakeServer({...defaultRoutes, ...routes});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        httpAdapterProvider.overrideWithValue(server),
      ],
      retry: (_, _) => null,
      child: const TradeHistoryApp(),
    ),
  );
  await tester.pumpAndSettle();

  return server;
}
