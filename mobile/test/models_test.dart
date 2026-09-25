import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/core/api_client.dart';
import 'package:trade_history/models/account.dart';
import 'package:trade_history/models/journal.dart';
import 'package:trade_history/models/stats.dart';
import 'package:trade_history/models/trade.dart';

import 'support.dart';

/// Model dibaca dari jawaban API sungguhan, bukan dari JSON karangan.
void main() {
  test('dashboard terbaca utuh, termasuk angka bulat dari PHP', () {
    final dashboard = Dashboard.fromJson(fixture('dashboard'));

    expect(dashboard.summary.currency, 'USC');
    expect(dashboard.summary.totalTrades, greaterThan(0));
    expect(dashboard.summary.bySymbol, isNotEmpty);
    expect(dashboard.equity, isNotEmpty);
    expect(dashboard.monthly, hasLength(12));
    expect(dashboard.ruleStatus.hasRules, isTrue);
    expect(dashboard.recent.first.id, isNot(matches(RegExp(r'^\d+$'))));
  });

  test('trade dan grupnya', () {
    final page = TradePage.fromJson(fixture('trades'));
    final grouped = page.items.where((trade) => trade.groupId != null).toList();

    expect(page.items, hasLength(25));
    expect(page.lastPage, greaterThan(1));
    expect(page.daily, isNotEmpty);
    expect(grouped, hasLength(2));
    expect(grouped.first.groupId, grouped.last.groupId);
    expect(page.items.first.stopState, isNotNull);
  });

  test('kalender: hari, pelanggaran, dan trade per tanggal', () {
    final month = CalendarMonth.fromJson(fixture('calendar'));

    expect(month.month, '2026-09');
    expect(month.gridStart.weekday, DateTime.monday);
    expect(month.gridEnd.weekday, DateTime.sunday);
    expect(month.days, isNotEmpty);
    expect(month.trades.keys.toSet(), month.days.keys.toSet());
  });

  test('array kosong dari PHP dibaca sebagai peta kosong', () {
    final month = CalendarMonth.fromJson({
      ...fixture('calendar'),
      'violations': <dynamic>[],
      'days': <dynamic>[],
      'trades': <dynamic>[],
    });

    expect(month.violations, isEmpty);
    expect(month.days, isEmpty);
  });

  test('dana, aturan, analisa, akun, laporan', () {
    final funds = TransactionsPage.fromJson(fixture('transactions'));
    final rules = RulesPage.fromJson(fixture('rules'));
    final analysis = AnalysisPage.fromJson(fixture('analysis'));
    final accounts = AccountsPage.fromJson(fixture('accounts'));
    final me = Me.fromJson(fixture('me'));

    expect(funds.year, isNull);
    expect(funds.items, isNotEmpty);
    expect(funds.items.first.hasProof, isA<bool>());
    expect(rules.rule.allowedSessions, containsAll(['london', 'newyork']));
    expect(rules.rule.maxDailyLossPct, 3);
    expect(rules.basis, greaterThan(0));
    expect(analysis.summary.totalTrades, greaterThan(0));
    expect(accounts.items.single.name, 'Demo XAUUSD');
    expect(me.accounts.single.startedAt, isNotNull);
    expect(ReportOptions.fromJson(fixture('reports')).years, isNotEmpty);
  });

  test('aturan dikirim balik dengan nama kolom server', () {
    const rule = RuleSettings(
      maxDailyLossPct: 2,
      allowedSessions: ['london'],
      notes: 'x',
    );

    expect(rule.toJson(), containsPair('max_daily_loss_pct', 2.0));
    expect(rule.toJson(), containsPair('max_daily_loss', null));
    expect(rule.toJson(), containsPair('allowed_sessions', ['london']));
  });

  group('galat API', () {
    ApiClient client(
      Map<String, Handler> routes, {
      void Function()? onUnauthorized,
    }) => ApiClient(
      server: 'trade.contoh.test',
      adapter: FakeServer(routes),
      onUnauthorized: onUnauthorized,
    );

    test('alamat tanpa skema jadi https tanpa garis miring', () {
      expect(
        normalizeServer(' trade.contoh.test/ '),
        'https://trade.contoh.test',
      );
      expect(normalizeServer('http://10.0.2.2:8000'), 'http://10.0.2.2:8000');
    });

    test(
      '422 membawa pesan per kolom, kunci bawaan Laravel diterjemahkan',
      () async {
        final api = client({
          'POST trades': (_) => const Reply(422, {
            'message': 'validation.required (and 1 more error)',
            'errors': {
              'pnl': ['validation.required'],
              'tp_price': [
                'Untuk posisi buy, take profit harus di atas harga entry.',
              ],
            },
          }),
        });

        await expectLater(
          api.post('trades', {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 422)
                .having((e) => e['pnl'], 'pnl', 'Wajib diisi.')
                .having(
                  (e) => e['tp_price'],
                  'tp',
                  startsWith('Untuk posisi buy'),
                ),
          ),
        );
      },
    );

    test('401 memanggil onUnauthorized supaya token dilupakan', () async {
      var expired = false;
      final api = client({
        'GET me': (_) => const Reply(401, {'message': 'Unauthenticated.'}),
      }, onUnauthorized: () => expired = true);

      await expectLater(
        api.get('me'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Sesi berakhir'),
          ),
        ),
      );
      expect(expired, isTrue);
    });

    test('pesan bawaan framework tidak tampil mentah', () async {
      final api = client({
        'GET x': (_) => const Reply(500, {'message': 'Server Error'}),
      });

      await expectLater(
        api.get('x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Server sedang bermasalah'),
          ),
        ),
      );
      await expectLater(
        api.get('tidak-ada'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('pesan dari controller sendiri ditampilkan apa adanya', () async {
      final api = client({
        'POST analysis': (_) => const Reply(502, {
          'message': 'Semua kunci Gemini baru saja dipakai.',
        }),
      });

      await expectLater(
        api.post('analysis'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Semua kunci Gemini baru saja dipakai.',
          ),
        ),
      );
    });

    test('token ikut di header', () async {
      final server = FakeServer({'GET me': (_) => fixture('me')});

      await ApiClient(
        server: 'x.test',
        token: 'abc',
        adapter: server,
      ).get('me');

      expect(server.requests.single.headers['Authorization'], 'Bearer abc');
      expect(server.requests.single.uri.toString(), 'https://x.test/api/v1/me');
    });
  });

  test('stop state dan hari efektif trade', () {
    final trade = Trade.fromJson({
      'id': 'abc',
      'symbol': 'XAUUSD',
      'direction': 'buy',
      'status': 'win',
      'pnl': 10,
      'stop_state': 'locked',
      'opened_at': '2026-09-24T23:00',
      'closed_at': '2026-09-25T01:00',
      'setup': 'FVG, CHoCH',
    });

    expect(trade.stopState, StopState.locked);
    expect(trade.dayKey, '2026-09-25');
    expect(trade.setups, ['FVG', 'CHoCH']);
  });
}
