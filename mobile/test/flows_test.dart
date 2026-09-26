import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/widgets/common.dart';
import 'package:trade_history/widgets/trade_widgets.dart';

import 'support.dart';

/// Alur yang tersembunyi di balik lembar bawah dan dialog — semuanya
/// dijalankan di layar 360 px supaya galat tata letak ketahuan di sini,
/// bukan di ponsel pengguna.
void main() {
  setUpAll(setUpFormatting);

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openMore(WidgetTester tester, String menu) async {
    await tester.tap(find.byTooltip('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menu).first);
    await tester.pumpAndSettle();
  }

  testWidgets('kalender: ketuk hari → rincian hari dan trade-nya', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Kalender');

    // Hari pertama yang punya trade di rekaman kalender.
    final day = fixture('calendar')['days'] as Map<String, dynamic>;
    final date = day.keys.first;
    final number = int.parse(date.substring(8));

    await tester.tap(find.text('$number').first);
    await tester.pumpAndSettle();

    expect(find.text('P/L hari ini'), findsOneWidget);
    expect(find.text('Total lot'), findsOneWidget);
  });

  testWidgets('filter trade dikirim sebagai query', (tester) async {
    final server = await pumpApp(tester);
    await openTab(tester, 'Trade');

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'EURUSD'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Loss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    final last = server.requests.lastWhere(
      (request) => request.path.endsWith('/trades'),
    );

    expect(last.queryParameters, containsPair('symbol', 'EURUSD'));
    expect(last.queryParameters, containsPair('status', 'loss'));
    expect(find.textContaining('2 filter aktif'), findsOneWidget);
  });

  testWidgets('grouping hanya menerima trade yang berurutan', (tester) async {
    final server = await pumpApp(
      tester,
      routes: {
        'POST accounts/1/trades/group': (_) => {
          'message': '2 trade jadi satu grup.',
          'group_id': 'x',
        },
      },
    );
    await openTab(tester, 'Trade');

    await tester.tap(find.byTooltip('Grouping'));
    await tester.pumpAndSettle();

    // Baris ke-4 (GBPUSD) bersebelahan dengan grup USDJPY di atasnya.
    final trades = (fixture('trades')['trades'] as Map)['data'] as List;
    final gbp = trades[3] as Map;
    final next = trades[4] as Map;

    Finder row(Map trade) => find.byWidgetPredicate(
      (widget) => widget is TradeRow && widget.trade.id == trade['id'],
    );

    // Baris yang tidak menempel di pilihan tidak bisa ikut dicentang.
    // Gulir sesedikit mungkin: baris pertama harus tetap ada di pohon.
    await Scrollable.ensureVisible(
      tester.element(row(gbp)),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    await tester.pumpAndSettle();
    await tester.tap(row(gbp));
    await tester.pumpAndSettle();
    await tester.tap(row(trades[0] as Map));
    await tester.pumpAndSettle();
    expect(find.text('Grouping 1 trade'), findsOneWidget);

    // Gulir sampai barisnya dibangun: daftar riwayat dibangun seperlunya,
    // jadi baris di bawah layar belum tentu ada di pohon widget.
    await tester.scrollUntilVisible(
      row(next),
      100,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(row(next));
    await tester.pumpAndSettle();

    expect(find.text('Grouping 2 trade'), findsOneWidget);

    await tester.tap(find.text('Grouping 2 trade'));
    await tester.pumpAndSettle();

    final request = server.requests.lastWhere(
      (request) => request.path.endsWith('trades/group'),
    );

    expect(request.data, {
      'ids': [gbp['id'], next['id']],
    });
    expect(find.text('2 trade jadi satu grup.'), findsOneWidget);
  });

  testWidgets('dana: form catat butuh bukti, form ubah tidak', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Dana');

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    expect(find.text('Catat transaksi'), findsOneWidget);
    expect(find.textContaining('Kurs rupiah'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah transaksi'), findsOneWidget);
    expect(
      find.text('Biarkan apa adanya kalau buktinya tidak berubah.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('dana: ketuk baris → detail transaksi, Ubah membuka form', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'Dana');

    await tester.ensureVisible(find.text('Withdrawal'));
    await tester.tap(find.text('Withdrawal'));
    await tester.pumpAndSettle();

    // Catatan tampil utuh sendiri, bukan tergabung dengan tanggal seperti di baris.
    expect(find.text('Ambil profit'), findsOneWidget);
    expect(find.text('Tidak ada bukti transfer.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ubah'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada bukti transfer.'), findsNothing);
    expect(find.text('Ubah transaksi'), findsOneWidget);
  });

  testWidgets('lupa sandi: kode dicek dulu, baru sandi baru, lalu masuk', (
    tester,
  ) async {
    const wrongCode = Reply(422, {
      'message': 'Kode salah atau sudah kedaluwarsa.',
      'errors': {
        'code': ['Kode salah atau sudah kedaluwarsa.'],
      },
    });
    final server = await pumpApp(
      tester,
      loggedIn: false,
      routes: {
        'POST auth/password/forgot': (request) =>
            (request.data as Map)['email'] == 'demo@contoh.com'
            ? {'message': 'Kode 4 digit sudah dikirim ke email kamu.'}
            : const Reply(422, {
                'message': 'Email ini belum terdaftar.',
                'errors': {
                  'email': ['Email ini belum terdaftar.'],
                },
              }),
        // 1111 lolos verifikasi, tapi kedaluwarsa sebelum sandi diganti.
        'POST auth/password/verify': (request) =>
            ['4821', '1111'].contains((request.data as Map)['code'])
            ? {'message': 'Kode benar.'}
            : wrongCode,
        'POST auth/password/reset': (request) =>
            (request.data as Map)['code'] == '4821'
            ? {'message': 'Kata sandi diganti.'}
            : wrongCode,
      },
    );

    Future<void> sendCode(String email) async {
      await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
      await tester.tap(find.text('Kirim kode'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    // Email salah ketik ditolak di langkah pertama.
    await sendCode('demo@contoh.co');
    expect(find.text('Email ini belum terdaftar.'), findsOneWidget);
    expect(find.text('Kode dari email'), findsNothing);

    await sendCode('demo@contoh.com');
    expect(find.text('Email ini belum terdaftar.'), findsNothing);
    expect(find.textContaining('Kode 4 digit sudah dikirim'), findsOneWidget);

    const password = 'Kata sandi baru (min. 8 karakter)';

    Future<void> verify(String code) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Kode dari email'),
        code,
      );
      await tester.tap(find.text('Verifikasi'));
      await tester.pumpAndSettle();
    }

    Future<void> changePassword() async {
      await tester.ensureVisible(find.text('Ganti sandi'));
      await tester.tap(find.text('Ganti sandi'));
      await tester.pumpAndSettle();
    }

    // Form sandi baru baru muncul setelah kodenya benar.
    expect(find.text(password), findsNothing);
    await verify('0000');
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(find.text(password), findsNothing);

    await verify('1111');
    expect(find.text('Kode dari email'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, password),
      'sandi-baru-123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ulangi kata sandi baru'),
      'sandi-baru-123',
    );

    // Kode kedaluwarsa selagi sandi diisi: kembali ke langkah kode, dan sandi
    // yang sudah diketik tidak perlu diulang.
    await changePassword();
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(find.text(password), findsNothing);

    await verify('4821');
    await changePassword();

    // Masuk dengan sandi baru, bukan sandi lama.
    final login = server.requests.lastWhere(
      (request) => request.path == 'auth/login',
    );
    expect((login.data as Map)['password'], 'sandi-baru-123');
    expect(find.text('Lupa kata sandi?'), findsNothing);
  });

  testWidgets(
    'perangkat: perangkat lain bisa dikeluarkan, perangkat ini tidak',
    (tester) async {
      final server = await pumpApp(
        tester,
        routes: {
          'DELETE devices/2': (_) => {'message': 'Perangkat dikeluarkan.'},
        },
      );

      await openMore(tester, 'Perangkat');

      expect(find.text('Infinix GT 30 Pro'), findsOneWidget);
      expect(find.text('Perangkat ini'), findsOneWidget);
      // Hanya iPhone yang punya tombol; perangkat ini keluar lewat menu Keluar.
      expect(find.widgetWithText(TextButton, 'Keluarkan'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Keluarkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Keluarkan'));
      await tester.pumpAndSettle();

      expect(
        server.requests.any(
          (request) =>
              request.method == 'DELETE' && request.path == 'devices/2',
        ),
        isTrue,
      );
      expect(find.text('Perangkat dikeluarkan.'), findsOneWidget);
    },
  );

  testWidgets('aturan: aturan persen lama disimpan ulang sebagai nominal', (
    tester,
  ) async {
    final server = await pumpApp(
      tester,
      routes: {
        'PUT accounts/1/rules': (_) => {'message': 'Aturan tersimpan.'},
      },
    );
    await openMore(tester, 'Aturan trading');

    await tester.scrollUntilVisible(
      find.text('Simpan aturan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan aturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan aturan'));
    await tester.pumpAndSettle();

    final saved =
        server.requests.lastWhere((request) => request.method == 'PUT').data
            as Map;

    // Basis 6200: 3% → 186, 1% → 62, 10% → 620. Kolom persennya dikosongkan.
    expect(saved['max_daily_loss'], 186);
    expect(saved['max_risk_per_trade'], 62);
    expect(saved['max_total_loss'], 620);
    expect(saved['max_daily_loss_pct'], isNull);
    expect(saved['max_total_loss_pct'], isNull);
    expect(saved['allowed_sessions'], containsAll(['london', 'newyork']));
    expect(find.text('Aturan tersimpan.'), findsOneWidget);
  });

  testWidgets('analisa AI tampil sebagai markdown, chat mendapat jawaban', (
    tester,
  ) async {
    final server = await pumpApp(
      tester,
      routes: {
        'GET accounts/1/analysis': (_) => {
          ...fixture('analysis'),
          'aiEnabled': true,
          'analysis': {
            'result_md': '## Pola menang\n- Winrate **65%** di sesi London.',
            'model': 'gemini-uji',
            'analyzed_at': '2026-09-24T10:00:00.000000Z',
            'period_start': '2026-08-26',
            'period_end': '2026-09-25',
            'stale': true,
          },
        },
        'POST accounts/1/analysis/chat': (_) => {
          'reply': 'Kelemahan terbesar: **cut loss terlambat**.',
        },
      },
    );
    await openMore(tester, 'Analisa');

    await tester.scrollUntilVisible(
      find.text('Pola menang'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pola menang'), findsOneWidget);
    expect(find.textContaining('data sudah berubah sejak itu'), findsOneWidget);

    await tester.tap(find.text('Tanya AI'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apa kelemahan terbesar cara trading saya?'));
    // Balasan diketik bertahap selama beberapa detik.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    final chat =
        server.requests
                .lastWhere((request) => request.path.endsWith('analysis/chat'))
                .data
            as Map;

    expect(chat['message'], 'Apa kelemahan terbesar cara trading saya?');
    expect(chat['history'], isEmpty);
    expect(
      find.textContaining('cut loss terlambat', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('beberapa akun: pengalih akun memuat ulang data akun kedua', (
    tester,
  ) async {
    final me = fixture('me');
    final accounts = [
      ...(me['accounts'] as List),
      {
        'id': 2,
        'name': 'Akun Rupiah',
        'broker': null,
        'currency': 'IDR',
        'initial_balance': 1000000,
        'started_at': '2026-01-01',
      },
    ];

    final server = await pumpApp(
      tester,
      routes: {
        'GET me': (_) => {...me, 'accounts': accounts},
        'GET accounts/2/dashboard': (_) => {
          ...fixture('dashboard'),
          'summary': {
            ...fixture('dashboard')['summary'] as Map<String, dynamic>,
            'currency': 'IDR',
          },
        },
      },
    );

    await tester.tap(find.text('Demo XAUUSD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun Rupiah'));
    await tester.pumpAndSettle();

    expect(
      server.requests.any((request) => request.path == 'accounts/2/dashboard'),
      isTrue,
    );
    expect(find.text('Akun Rupiah'), findsOneWidget);
    expect(find.textContaining('Rp'), findsWidgets);
  });

  testWidgets('akun baru tanpa modal awal, langsung ke deposit pertama', (
    tester,
  ) async {
    final server = await pumpApp(
      tester,
      routes: {
        'POST accounts': (_) => {'message': 'Akun dibuat.', 'id': 1},
      },
    );
    await openMore(tester, 'Akun trading');

    await tester.tap(find.text('Akun baru'));
    await tester.pumpAndSettle();

    expect(find.text('Nama akun *'), findsOneWidget);
    expect(find.textContaining('Nomor akun broker'), findsOneWidget);
    expect(find.text('Arsipkan'), findsNothing);
    expect(find.textContaining('Saldo awal'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nama akun *'),
      'Akun Baru',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final saved =
        server.requests.lastWhere((request) => request.method == 'POST').data
            as Map;

    expect(saved.containsKey('initial_balance'), isFalse);
    expect(find.text('Catat transaksi'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Segments && w.value == 'deposit'),
      findsOneWidget,
    );
  });

  testWidgets('ganti periode dari grafik P/L tidak melempar gulir ke atas', (
    tester,
  ) async {
    await pumpApp(tester);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('P/L periode'),
      300,
      scrollable: list,
    );
    await tester.pumpAndSettle();

    final before = tester.state<ScrollableState>(list).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.text('90 hari').last);
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(list).position.pixels, before);
  });

  // Gestur kembali Android (predictive back) dari layar chat: dulu ikut
  // menutup halaman Analisa yang tertimpa di bawahnya, jadi mendarat di
  // Lainnya.
  testWidgets('gestur kembali dari Tanya AI mendarat di Analisa', (
    tester,
  ) async {
    await pumpApp(
      tester,
      routes: {
        'GET accounts/1/analysis': (_) => {
          ...fixture('analysis'),
          'aiEnabled': true,
        },
      },
    );
    await openMore(tester, 'Analisa');
    await tester.tap(find.text('Tanya AI'));
    await tester.pumpAndSettle();
    expect(find.text('Berdasarkan statistik akun ini.'), findsOneWidget);

    Future<void> send(String method, [Object? args]) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
    final event = {
      'touchOffset': [5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    };

    await send('startBackGesture', event);
    await tester.pump();
    await send('updateBackGestureProgress', {...event, 'progress': .6});
    await tester.pump();
    await send('commitBackGesture');
    await tester.pumpAndSettle();

    expect(find.text('Berdasarkan statistik akun ini.'), findsNothing);
    expect(find.textContaining('Statistik dihitung'), findsOneWidget);
  });

  testWidgets('kartu analisa membandingkan dengan periode sebelumnya', (
    tester,
  ) async {
    await pumpApp(
      tester,
      routes: {
        'GET accounts/1/analysis': (_) => {
          ...fixture('analysis'),
          'previous': {
            'net_pnl': 9999.0,
            'win_rate_pct': 40.0,
            'profit_factor': 1.1,
          },
        },
      },
    );
    await openMore(tester, 'Analisa');

    // Winrate & profit factor membaik, P/L turun dari 9.999.
    expect(find.text('dari 40,0%'), findsOneWidget);
    expect(find.text('dari 1,10'), findsOneWidget);
    expect(find.textContaining('dari +9.999'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNWidgets(2));
    expect(find.text('Panah: dibanding 30 hari sebelumnya.'), findsOneWidget);
  });
}
