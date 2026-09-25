import '../core/format.dart';
import '../core/json.dart';
import 'stats.dart';

/// Setoran atau penarikan dana. Bukti transfernya diambil terpisah lewat
/// `transactions/{id}/proof` dengan token yang sama.
class FundTransaction {
  const FundTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.rateIdr,
    required this.occurredAt,
    required this.note,
    required this.hasProof,
    this.proofVersion,
  });

  factory FundTransaction.fromJson(Json json) => FundTransaction(
    id: '${json['id']}',
    type: '${json['type']}',
    amount: toDouble(json['amount']),
    rateIdr: toDoubleOrNull(json['rate_idr']),
    occurredAt: wallTime('${json['occurred_at']}'),
    note: toStringOrNull(json['note']),
    hasProof: json['has_proof'] == true,
    proofVersion: toStringOrNull(json['proof_version']),
  );

  final String id;

  /// `deposit` atau `withdrawal`.
  final String type;
  final double amount;
  final double? rateIdr;
  final DateTime occurredAt;
  final String? note;
  final bool hasProof;

  /// Berganti saat buktinya diganti; ikut di alamat gambar (lihat `proofUrl`).
  final String? proofVersion;

  bool get isDeposit => type == 'deposit';

  /// Positif untuk setoran, negatif untuk penarikan.
  double get signed => isDeposit ? amount : -amount;
}

class TransactionTotals {
  const TransactionTotals({
    required this.deposit,
    required this.withdrawal,
    required this.depositIdr,
    required this.withdrawalIdr,
    required this.balance,
    required this.initialBalance,
  });

  factory TransactionTotals.fromJson(Json json) => TransactionTotals(
    deposit: toDouble(json['deposit']),
    withdrawal: toDouble(json['withdrawal']),
    depositIdr: toDouble(json['deposit_idr']),
    withdrawalIdr: toDouble(json['withdrawal_idr']),
    balance: toDouble(json['balance']),
    initialBalance: toDouble(json['initial_balance']),
  );

  final double deposit;
  final double withdrawal;
  final double depositIdr;
  final double withdrawalIdr;
  final double balance;
  final double initialBalance;
}

class TransactionsPage {
  const TransactionsPage({
    required this.year,
    required this.month,
    required this.years,
    required this.items,
    required this.page,
    required this.lastPage,
    required this.totals,
  });

  factory TransactionsPage.fromJson(Json json) {
    final filters = map(json['filters']);
    final items = map(json['items']);

    return TransactionsPage(
      year: toIntOrNull(filters['year']),
      month: toIntOrNull(filters['month']),
      years: list(json['years']).map(toInt).toList(),
      items: list(items['data'])
          .map((item) => FundTransaction.fromJson(map(item)))
          .toList(),
      page: toInt(items['current_page']),
      lastPage: toInt(items['last_page']),
      totals: TransactionTotals.fromJson(map(json['totals'])),
    );
  }

  /// null = semua tahun / semua bulan.
  final int? year;
  final int? month;
  final List<int> years;
  final List<FundTransaction> items;
  final int page;
  final int lastPage;
  final TransactionTotals totals;
}

/// Isian `account_rules`. Semuanya catatan + indikator; tidak ada yang memblokir.
class RuleSettings {
  const RuleSettings({
    this.maxDailyLoss,
    this.maxDailyLossPct,
    this.dailyProfitTarget,
    this.dailyProfitTargetPct,
    this.maxTotalLossPct,
    this.maxRiskPerTradePct,
    this.maxTradesPerDay,
    this.minRr,
    this.allowedSessions = const [],
    this.notes = '',
  });

  factory RuleSettings.fromJson(Json json) => RuleSettings(
    maxDailyLoss: toDoubleOrNull(json['max_daily_loss']),
    maxDailyLossPct: toDoubleOrNull(json['max_daily_loss_pct']),
    dailyProfitTarget: toDoubleOrNull(json['daily_profit_target']),
    dailyProfitTargetPct: toDoubleOrNull(json['daily_profit_target_pct']),
    maxTotalLossPct: toDoubleOrNull(json['max_total_loss_pct']),
    maxRiskPerTradePct: toDoubleOrNull(json['max_risk_per_trade_pct']),
    maxTradesPerDay: toIntOrNull(json['max_trades_per_day']),
    minRr: toDoubleOrNull(json['min_rr']),
    allowedSessions: strings(json['allowed_sessions']),
    notes: '${json['notes'] ?? ''}',
  );

  final double? maxDailyLoss;
  final double? maxDailyLossPct;
  final double? dailyProfitTarget;
  final double? dailyProfitTargetPct;
  final double? maxTotalLossPct;
  final double? maxRiskPerTradePct;
  final int? maxTradesPerDay;
  final double? minRr;
  final List<String> allowedSessions;
  final String notes;

  Json toJson() => {
    'max_daily_loss': maxDailyLoss,
    'max_daily_loss_pct': maxDailyLossPct,
    'daily_profit_target': dailyProfitTarget,
    'daily_profit_target_pct': dailyProfitTargetPct,
    'max_total_loss_pct': maxTotalLossPct,
    'max_risk_per_trade_pct': maxRiskPerTradePct,
    'max_trades_per_day': maxTradesPerDay,
    'min_rr': minRr,
    'allowed_sessions': allowedSessions,
    'notes': notes,
  };
}

class RulesPage {
  const RulesPage({
    required this.rule,
    required this.status,
    required this.basis,
  });

  factory RulesPage.fromJson(Json json) => RulesPage(
    rule: RuleSettings.fromJson(map(json['rule'])),
    status: RuleStatus.fromJson(map(json['status'])),
    basis: toDouble(json['basis']),
  );

  final RuleSettings rule;
  final RuleStatus status;

  /// Modal awal + dana masuk/keluar: dasar perkiraan aturan berbentuk persen.
  final double basis;
}

class SavedAnalysis {
  const SavedAnalysis({
    required this.markdown,
    required this.model,
    required this.analyzedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.stale,
  });

  factory SavedAnalysis.fromJson(Json json) => SavedAnalysis(
    markdown: '${json['result_md'] ?? ''}',
    model: '${json['model'] ?? ''}',
    analyzedAt: instantOrNull(json['analyzed_at']),
    periodStart: wallTime('${json['period_start']}'),
    periodEnd: wallTime('${json['period_end']}'),
    stale: json['stale'] == true,
  );

  final String markdown;
  final String model;
  final DateTime? analyzedAt;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Statistik sudah berubah sejak analisa ini ditulis.
  final bool stale;
}

class AnalysisPage {
  const AnalysisPage({
    required this.period,
    required this.summary,
    required this.aiEnabled,
    required this.model,
    required this.analysis,
  });

  factory AnalysisPage.fromJson(Json json) => AnalysisPage(
    period: '${json['period']}',
    summary: Summary.fromJson(map(json['summary'])),
    aiEnabled: json['aiEnabled'] == true,
    model: '${json['model'] ?? ''}',
    analysis: json['analysis'] is Map
        ? SavedAnalysis.fromJson(map(json['analysis']))
        : null,
  );

  final String period;
  final Summary summary;
  final bool aiEnabled;
  final String model;
  final SavedAnalysis? analysis;
}

class ReportOptions {
  const ReportOptions({
    required this.years,
    required this.defaultName,
    required this.accounts,
  });

  factory ReportOptions.fromJson(Json json) => ReportOptions(
    years: list(json['years']).map(toInt).toList(),
    defaultName: '${json['defaultName'] ?? ''}',
    accounts: list(json['accounts']).map((item) => map(item)).toList(),
  );

  final List<int> years;
  final String defaultName;

  /// `{id, name, broker, currency, is_archived}` — termasuk akun yang diarsipkan.
  final List<Json> accounts;
}

/// Satu giliran percakapan dengan AI.
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  factory ChatMessage.fromJson(Json json) =>
      ChatMessage(role: '${json['role']}', text: '${json['text']}');

  /// `user` atau `assistant`.
  final String role;
  final String text;

  bool get mine => role == 'user';

  Json toJson() => {'role': role, 'text': text};
}
