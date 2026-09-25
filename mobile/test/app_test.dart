import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trade_history/features/auth/login_screen.dart';

import 'support.dart';

/// Aplikasi utuh dijalankan di layar 360 px dengan jawaban server rekaman.
/// Yang dijaga: tiap layar benar-benar tampil (tanpa galat tata letak di
/// layar sempit), dan aksi utama mengirim permintaan yang benar.
void main() {
  setUpAll(setUpFormatting);

  testWidgets('belum masuk → layar login, lalu masuk ke dashboard', (
    tester,
  ) async {
    final server = await pumpApp(
      tester,
      loggedIn: false,
      routes: {
        'GET auth/options': (_) => {
          'app_name': 'Trade History',
          'can_register': true,
        },
      },
    );

    expect(find.text('Masuk ke jurnal trading kamu.'), findsOneWidget);
    expect(find.text('Alamat server'), findsNothing);
    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'demo@contoh.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kata sandi'),
      'rahasia123',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    final login = server.requests.firstWhere(
      (request) => request.path == 'auth/login',
    );
    expect(login.data, containsPair('email', 'demo@contoh.com'));
    expect(login.data, contains('device_name'));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Demo XAUUSD'), findsOneWidget);
  });

  testWidgets('pemasangan baru: perkenalan dulu, sekali saja', (tester) async {
    await pumpApp(tester, loggedIn: false, onboarded: false);

    expect(find.text('Jurnal yang mencatat semuanya'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Isi dari screenshot'), findsOneWidget);

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke jurnal trading kamu.'), findsOneWidget);

    // Kembali ke awal aplikasi tidak memunculkannya lagi.
    GoRouter.of(tester.element(find.byType(LoginScreen))).go('/');
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke jurnal trading kamu.'), findsOneWidget);
  });

  testWidgets('perkenalan: slide terakhir tidak menggeser isinya', (
    tester,
  ) async {
    await pumpApp(tester, loggedIn: false, onboarded: false);

    final top = tester.getTopLeft(find.byType(PageView));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Mulai'), findsOneWidget);
    // "Lewati" disembunyikan, tapi tempatnya tetap.
    expect(tester.getTopLeft(find.byType(PageView)), top);
  });

  testWidgets('pemilih akun dengan banyak akun tetap bisa digulir', (
    tester,
  ) async {
    final me = fixture('me');
    final base = (me['accounts'] as List).first as Map<String, dynamic>;
    me['accounts'] = [
      for (var i = 1; i <= 12; i++) {...base, 'id': i, 'name': 'Akun $i'},
    ];
    await pumpApp(tester, routes: {'GET me': (_) => me});

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    // Judul dan "Kelola akun" tetap di tempat; daftarnya yang digulir.
    expect(find.text('Kelola akun'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Akun 12'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Akun 12'), findsOneWidget);
  });

  testWidgets('ponsel miring: lembar dan dialog tetap muat', (tester) async {
    await pumpApp(tester);

    // Dialog berkode, lalu ponsel dimiringkan dengan keyboard terbuka:
    // sisa tingginya sempit sekali.
    await tester.tap(find.text('Dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Batal'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    // Lembar foto profil lebih tinggi dari layar miring: isinya digulir.
    await tester.tap(find.byTooltip('Foto profil').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Profil'),
      50,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('FAB di tab lain tidak bentrok saat membuka form trade', (
    tester,
  ) async {
    await pumpApp(tester);

    // Halaman akun (FAB "Akun baru") tetap hidup di tab Lainnya.
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun trading').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trade').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Trade'));
    await tester.pumpAndSettle();

    expect(find.text('Trade baru'), findsOneWidget);
  });

  testWidgets('dashboard tanpa trade menunjukkan langkah pertama', (
    tester,
  ) async {
    final empty = fixture('dashboard')..['recent'] = [];
    await pumpApp(tester, routes: {'GET accounts/1/dashboard': (_) => empty});

    expect(find.text('Mulai di sini'), findsOneWidget);

    await tester.tap(find.text('Atur batas harian'));
    await tester.pumpAndSettle();
    expect(find.text('Aturan trading'), findsWidgets);
  });

  testWidgets('login yang ditolak menampilkan alasannya', (tester) async {
    await pumpApp(
      tester,
      loggedIn: false,
      routes: {
        'POST auth/login': (_) => const Reply(422, {
          'message': 'Email atau kata sandi tidak cocok.',
          'errors': {
            'email': ['Email atau kata sandi tidak cocok.'],
          },
        }),
      },
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'salah@contoh.com',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi tidak cocok.'), findsOneWidget);
    expect(find.text('Masuk ke jurnal trading kamu.'), findsOneWidget);
  });

  testWidgets('kembali dari layar daftar, tautan "Daftar" langsung ada', (
    tester,
  ) async {
    final server = await pumpApp(
      tester,
      loggedIn: false,
      routes: {
        'GET auth/options': (_) => {
          'app_name': 'Trade History',
          'can_register': true,
        },
      },
    );

    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah punya akun? Masuk'));
    // Dua frame: router membangun ulang, lalu layar login tampil. Belum ada
    // kesempatan menunggu server — jawaban pertama masih diingat.
    await tester.pump();
    await tester.pump();

    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);
    expect(
      server.requests.where((request) => request.path == 'auth/options'),
      hasLength(1),
    );
  });

  testWidgets(
    'dashboard: kartu angka, kurva, aturan hari ini, trade terakhir',
    (tester) async {
      await pumpApp(tester);

      expect(find.text('SALDO'), findsOneWidget);
      expect(find.text('17.653,00 USC'), findsOneWidget);
      expect(find.text('Perkembangan akun'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Hari ini'), 300);
      expect(find.text('Hari ini'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Trade terakhir'), 300);
      expect(find.text('Trade terakhir'), findsOneWidget);
    },
  );

  testWidgets('semua tab dan halaman "Lainnya" tampil tanpa galat', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Kalender'));
    await tester.pumpAndSettle();
    expect(find.text('Sen'), findsOneWidget);
    expect(find.textContaining('hari hijau'), findsOneWidget);

    await tester.tap(find.text('Trade').last);
    await tester.pumpAndSettle();
    expect(find.text('Riwayat trade'), findsOneWidget);
    expect(find.textContaining('trade tercatat'), findsOneWidget);

    await tester.tap(find.text('Dana'));
    await tester.pumpAndSettle();
    expect(find.text('SALDO SEKARANG'), findsOneWidget);

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();

    for (final (menu, marker) in [
      ('Aturan trading', 'Catatan pribadi'),
      ('Analisa', 'Statistik dihitung'),
      ('Laporan tahunan', 'Berkas PDF A4'),
      ('Akun trading', 'Tiap akun punya riwayat'),
      ('Profil', 'Data login kamu.'),
    ]) {
      await tester.tap(find.text(menu).first);
      await tester.pumpAndSettle();
      expect(find.textContaining(marker), findsWidgets, reason: menu);

      // `pageBack()` mencari tooltip "Back"; aplikasinya berbahasa Indonesia.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('detail trade bergrup bisa mengubah grupnya', (tester) async {
    final server = await pumpApp(
      tester,
      routes: {
        'PUT accounts/1/trades/group/.+': (_) => {
          'message': 'Grup diperbarui.',
        },
      },
    );

    await tester.tap(find.text('Trade').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('USDJPY').first);
    await tester.pumpAndSettle();

    expect(find.text('Satu grup dengan 1 trade lain'), findsOneWidget);
    expect(find.text('Entry'), findsOneWidget);

    await tester.ensureVisible(find.text('Simpan grup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan grup'));
    await tester.pumpAndSettle();

    expect(
      server.requests.where((request) => request.method == 'PUT'),
      hasLength(1),
    );
    expect(find.text('Grup diperbarui.'), findsOneWidget);
  });

  testWidgets(
    'form trade: umpan balik TP salah sisi, RR rencana, lalu simpan',
    (tester) async {
      final server = await pumpApp(
        tester,
        routes: {
          'POST accounts/1/trades': (_) =>
              const Reply(201, {'message': 'Trade XAUUSD tersimpan.'}),
        },
      );

      await tester.tap(find.text('Trade').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Trade baru'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Simbol *'),
        'xauusd',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Entry *'), '2400');
      await tester.enterText(
        find.widgetWithText(TextField, 'Stop loss'),
        '2390',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Take profit'),
        '2380',
      );
      await tester.pumpAndSettle();

      expect(find.text('TP harus di atas entry.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Take profit'),
        '2430',
      );
      await tester.pumpAndSettle();

      expect(find.text('TP harus di atas entry.'), findsNothing);
      expect(find.textContaining('3,00R'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Hasil (USC) *'),
        '150,5',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan').first);
      await tester.pumpAndSettle();

      final saved = jsonDecode(
        jsonEncode(server.requests.firstWhere((r) => r.method == 'POST').data),
      ) as Map;

      expect(saved['symbol'], 'XAUUSD');
      expect(saved['entry_price'], 2400);
      expect(saved['pnl'], 150.5);
      expect(saved['closed_at'], saved['opened_at']);
      expect(saved['source'], 'manual');
      expect(find.text('Riwayat trade'), findsOneWidget);
      expect(find.text('Trade XAUUSD tersimpan.'), findsOneWidget);
    },
  );

  testWidgets('galat isian dari server tampil di kolomnya', (tester) async {
    await pumpApp(
      tester,
      routes: {
        'POST accounts/1/trades': (_) => const Reply(422, {
          'message': 'validation.required',
          'errors': {
            'symbol': ['validation.required'],
            'pnl': ['validation.required'],
          },
        }),
      },
    );

    await tester.tap(find.text('Trade').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan').first);
    await tester.pumpAndSettle();

    expect(find.text('Wajib diisi.'), findsWidgets);
    expect(find.text('Trade baru'), findsOneWidget);
  });

  testWidgets('keluar mencabut token dan kembali ke login', (tester) async {
    final server = await pumpApp(tester);

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(
      server.requests.any((request) => request.path == 'auth/logout'),
      isTrue,
    );
    expect(find.text('Masuk ke jurnal trading kamu.'), findsOneWidget);
  });
}
