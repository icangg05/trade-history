import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/json.dart';
import '../models/account.dart';
import 'journal_api.dart';

/// Diisi di `main()` — SharedPreferences sudah dimuat sebelum aplikasi jalan.
final prefsProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError('prefsProvider'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Penyambung HTTP Dio. Hanya diganti di test, supaya layar bisa dijalankan
/// dengan jawaban server rekaman tanpa jaringan.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Alamat server, ditanam saat build: `--dart-define=API_BASE_URL=https://…`.
const defaultServer = String.fromEnvironment('API_BASE_URL');

const _serverKey = 'server';
const _tokenKey = 'token';
const _accountKey = 'account_id';

/// Server yang dituju. Alamat dari build selalu menang — tidak ada lagi isian
/// alamat di layar masuk, jadi alamat lama yang tersimpan tidak boleh
/// mengunci aplikasi ke server yang salah. Yang tersimpan hanya dipakai kalau
/// build tidak membawa alamat (test).
class ServerController extends Notifier<String> {
  @override
  String build() => defaultServer.isNotEmpty
      ? normalizeServer(defaultServer)
      : ref.read(prefsProvider).getString(_serverKey) ?? '';

  Future<void> set(String value) async {
    state = normalizeServer(value);
    await ref.read(prefsProvider).setString(_serverKey, state);
  }
}

final serverProvider = NotifierProvider<ServerController, String>(
  ServerController.new,
);

/// Token Sanctum milik perangkat ini. Disimpan di Keychain / Keystore, bukan
/// di SharedPreferences biasa.
class Session {
  const Session({required this.server, required this.token});

  final String server;
  final String token;
}

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final token = await ref.read(secureStorageProvider).read(key: _tokenKey);
    final server = ref.read(serverProvider);

    return token == null || server.isEmpty
        ? null
        : Session(server: server, token: token);
  }

  Future<void> login({
    required String server,
    required String email,
    required String password,
  }) => _signIn(server, 'auth/login', {'email': email, 'password': password});

  Future<void> register({
    required String server,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String token,
  }) => _signIn(server, 'auth/register', {
    'name': name,
    'email': email,
    'password': password,
    'password_confirmation': passwordConfirmation,
    'token': token,
  });

  Future<void> _signIn(String server, String path, Json body) async {
    final json = await ApiClient(
      server: server,
      adapter: ref.read(httpAdapterProvider),
    ).post(path, {...body, 'device_name': _deviceName()});

    await ref.read(serverProvider.notifier).set(server);
    await ref
        .read(secureStorageProvider)
        .write(key: _tokenKey, value: '${json['token']}');

    state = AsyncData(
      Session(server: normalizeServer(server), token: '${json['token']}'),
    );
  }

  /// Keluar dari perangkat ini: token dicabut di server, lalu dilupakan di sini.
  Future<void> logout() async {
    final session = state.value;

    try {
      // Klien dibuat langsung dari sesi ini: `apiClientProvider` bergantung
      // pada notifier ini, jadi membacanya dari sini adalah lingkaran.
      if (session != null) {
        await ApiClient(
          server: session.server,
          token: session.token,
          adapter: ref.read(httpAdapterProvider),
        ).post('auth/logout');
      }
    } on ApiException {
      // Token yang sudah mati di server tetap harus dilupakan di ponsel.
    }

    await forget();
  }

  /// Token ditolak server (dicabut dari perangkat lain, sandi diganti, akun
  /// dihapus): lupakan tanpa bertanya ke server lagi.
  Future<void> forget() async {
    await ref.read(secureStorageProvider).delete(key: _tokenKey);
    await ref.read(prefsProvider).remove(_accountKey);

    state = const AsyncData(null);
  }

  static String _deviceName() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone / iPad',
    _ => 'Aplikasi mobile',
  };
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(
  SessionController.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionProvider).value;

  return ApiClient(
    server: session?.server ?? ref.watch(serverProvider),
    token: session?.token,
    adapter: ref.watch(httpAdapterProvider),
    onUnauthorized: () {
      if (ref.read(sessionProvider).value != null) {
        ref.read(sessionProvider.notifier).forget();
      }
    },
  );
});

final journalProvider = Provider<JournalApi>(
  (ref) => JournalApi(ref.watch(apiClientProvider)),
);

/// Dinaikkan setiap kali sesuatu disimpan. Semua data layar menontonnya,
/// jadi dashboard, kalender, dan daftar trade ikut segar tanpa diurus satu per satu.
class Revision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final revisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Pengguna dan akun yang bisa dibuka. Tidak ikut `revisionProvider`: daftar
/// akun hanya berubah lewat halaman akun & profil, yang memuat ulang sendiri.
final meProvider = FutureProvider<Me>((ref) => ref.watch(journalProvider).me());

/// Akun yang dipilih di pengalih akun, diingat antar-buka aplikasi.
class SelectedAccount extends Notifier<int?> {
  @override
  int? build() => ref.read(prefsProvider).getInt(_accountKey);

  Future<void> select(int id) async {
    state = id;
    await ref.read(prefsProvider).setInt(_accountKey, id);
  }
}

final selectedAccountProvider = NotifierProvider<SelectedAccount, int?>(
  SelectedAccount.new,
);

/// Akun yang sedang dibuka. Pilihan yang sudah tidak ada (dihapus, diarsipkan)
/// jatuh ke akun pertama — sama seperti `SetCurrentAccount` di web.
final currentAccountProvider = FutureProvider<AccountBrief?>((ref) async {
  final me = await ref.watch(meProvider.future);
  final selected = ref.watch(selectedAccountProvider);

  for (final account in me.accounts) {
    if (account.id == selected) return account;
  }

  return me.accounts.isEmpty ? null : me.accounts.first;
});
