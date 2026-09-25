import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await openTab(tester, 'Lainnya');
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
    await tester.tap(row(gbp));
    await tester.pumpAndSettle();
    await tester.tap(row(trades[0] as Map));
    await tester.pumpAndSettle();
    expect(find.text('Grouping 1 trade'), findsOneWidget);

    await tester.ensureVisible(row(next));
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

  testWidgets('aturan: batas harian dalam persen disimpan ke kolom persen', (
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

    expect(saved['max_daily_loss_pct'], 3);
    expect(saved['max_daily_loss'], isNull);
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

  testWidgets('akun: form akun baru', (tester) async {
    await pumpApp(tester);
    await openMore(tester, 'Akun trading');

    await tester.tap(find.text('Akun baru'));
    await tester.pumpAndSettle();

    expect(find.text('Nama akun *'), findsOneWidget);
    expect(find.textContaining('Nomor akun broker'), findsOneWidget);
    expect(find.text('Arsipkan'), findsNothing);
  });
}
