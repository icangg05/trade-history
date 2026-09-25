import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/json.dart';
import '../models/account.dart';
import '../models/journal.dart';
import '../models/stats.dart';
import '../models/trade.dart';

/// Semua pintu `/api/v1` yang dipakai layar, dalam bentuk bertipe. Satu akun
/// dibuka lewat alamatnya (`accounts/{id}/…`), bukan lewat sesi seperti di web.
class JournalApi {
  JournalApi(this.client);

  final ApiClient client;

  String _in(int account, String path) => 'accounts/$account/$path';

  static String _message(Json json, [String fallback = 'Tersimpan.']) =>
      '${json['message'] ?? fallback}';

  // ---------------------------------------------------------------- pengguna

  Future<Me> me() async => Me.fromJson(await client.get('me'));

  Future<Json> profile() => client.get('profile');

  Future<String> updateProfile(Json data) async =>
      _message(await client.put('profile', data));

  Future<String> deleteProfile(String password) async =>
      _message(await client.delete('profile', {'password': password}));

  // -------------------------------------------------------------------- akun

  Future<AccountsPage> accounts() async =>
      AccountsPage.fromJson(await client.get('accounts'));

  /// Mengembalikan pesan dan — untuk akun baru — id-nya.
  Future<(String, int?)> saveAccount(int? id, Json data) async {
    final json = id == null
        ? await client.post('accounts', data)
        : await client.put('accounts/$id', data);

    return (_message(json), toIntOrNull(json['id']));
  }

  Future<String> deleteAccount(int id) async =>
      _message(await client.delete('accounts/$id'));

  // -------------------------------------------------------------- ringkasan

  Future<Dashboard> dashboard(int account, String range) async =>
      Dashboard.fromJson(
        await client.get(_in(account, 'dashboard'), query: {'range': range}),
      );

  Future<CalendarMonth> calendar(int account, String month) async =>
      CalendarMonth.fromJson(
        await client.get(_in(account, 'calendar'), query: {'month': month}),
      );

  // ------------------------------------------------------------------- trade

  Future<TradePage> trades(int account, TradeFilters filters, int page) async =>
      TradePage.fromJson(
        await client.get(
          _in(account, 'trades'),
          query: {...filters.toQuery(), 'page': page},
        ),
      );

  /// Isi form: trade yang diubah (null untuk trade baru) dan apakah import AI aktif.
  Future<(Trade?, bool)> tradeForm(int account, String? id) async {
    final json = await client.get(
      _in(account, id == null ? 'trades/create' : 'trades/$id'),
    );

    return (
      json['trade'] is Map ? Trade.fromJson(map(json['trade'])) : null,
      json['aiEnabled'] == true,
    );
  }

  Future<String> saveTrade(int account, String? id, Json data) async =>
      _message(
        id == null
            ? await client.post(_in(account, 'trades'), data)
            : await client.put(_in(account, 'trades/$id'), data),
      );

  Future<String> deleteTrade(int account, String id) async =>
      _message(await client.delete(_in(account, 'trades/$id')));

  /// Screenshot dibaca Gemini sekali lalu dibuang — server tidak menyimpannya.
  Future<ExtractResult> extract(int account, XFile image) async =>
      ExtractResult.fromJson(
        await client.post(
          _in(account, 'trades/extract'),
          FormData.fromMap({'screenshot': await _file(image)}),
        ),
      );

  Future<String> group(int account, List<String> ids) async =>
      _message(await client.post(_in(account, 'trades/group'), {'ids': ids}));

  Future<String> updateGroup(
    int account,
    String group, {
    required String setup,
    required String notes,
  }) async => _message(
    await client.put(_in(account, 'trades/group/$group'), {
      'setup': setup,
      'notes': notes,
    }),
  );

  Future<String> ungroup(int account, String tradeId) async =>
      _message(await client.delete(_in(account, 'trades/$tradeId/group')));

  // -------------------------------------------------------------------- dana

  Future<TransactionsPage> transactions(
    int account, {
    required String year,
    required String month,
    int page = 1,
  }) async => TransactionsPage.fromJson(
    await client.get(
      _in(account, 'transactions'),
      query: {'year': year, 'month': month, 'page': page},
    ),
  );

  /// Multipart lewat POST, baik mencatat maupun memperbaiki — bukti ikut dikirim.
  Future<String> saveTransaction(
    int account,
    String? id,
    Json fields, {
    XFile? proof,
  }) async {
    final form = FormData.fromMap({
      for (final entry in fields.entries)
        if (entry.value != null) entry.key: '${entry.value}',
      if (proof != null) 'proof': await _file(proof),
    });

    return _message(
      await client.post(
        _in(account, id == null ? 'transactions' : 'transactions/$id'),
        form,
      ),
    );
  }

  Future<String> deleteTransaction(int account, String id) async =>
      _message(await client.delete(_in(account, 'transactions/$id')));

  String proofUrl(int account, String id) =>
      client.url(_in(account, 'transactions/$id/proof'));

  // ------------------------------------------------------------------ aturan

  Future<RulesPage> rules(int account) async =>
      RulesPage.fromJson(await client.get(_in(account, 'rules')));

  Future<String> saveRules(int account, RuleSettings rule) async =>
      _message(await client.put(_in(account, 'rules'), rule.toJson()));

  // ------------------------------------------------------------------ analisa

  Future<AnalysisPage> analysis(int account, String period) async =>
      AnalysisPage.fromJson(
        await client.get(_in(account, 'analysis'), query: {'period': period}),
      );

  Future<String> generateAnalysis(int account, String period) async =>
      _message(await client.post(_in(account, 'analysis'), {'period': period}));

  Future<String> chat(
    int account,
    String period,
    String message,
    List<ChatMessage> history,
  ) async {
    final json = await client.post(_in(account, 'analysis/chat'), {
      'period': period,
      'message': message,
      'history': history.map((turn) => turn.toJson()).toList(),
    });

    return '${json['reply'] ?? ''}';
  }

  // ----------------------------------------------------------------- laporan

  Future<ReportOptions> reportOptions() async =>
      ReportOptions.fromJson(await client.get('reports'));

  Future<Uint8List> reportPdf(Json data) =>
      client.download('reports/pdf', data: data);

  static Future<MultipartFile> _file(XFile file) async =>
      MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name);
}
