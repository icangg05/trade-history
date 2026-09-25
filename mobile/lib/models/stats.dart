import '../core/format.dart';
import '../core/json.dart';
import 'trade.dart';

class BreakdownRow {
  const BreakdownRow({
    required this.trades,
    required this.pnl,
    required this.winRate,
  });

  factory BreakdownRow.fromJson(Json json) => BreakdownRow(
    trades: toInt(json['trades']),
    pnl: toDouble(json['pnl']),
    winRate: toDouble(json['win_rate_pct']),
  );

  final int trades;
  final double pnl;
  final double winRate;
}

Map<String, BreakdownRow> _breakdown(Object? value) =>
    map(value)
        .map((key, row) => MapEntry(key, BreakdownRow.fromJson(map(row))));

Map<String, List<String>> violationsFrom(Object? value) =>
    map(value).map((date, reasons) => MapEntry(date, strings(reasons)));

/// `AccountStats::summary()` — statistik satu periode. Angkanya dihitung di
/// server; aplikasi hanya menampilkan.
class Summary {
  const Summary({
    required this.from,
    required this.to,
    required this.currency,
    required this.initialBalance,
    required this.balance,
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.winRate,
    required this.netPnl,
    required this.profitFactor,
    required this.expectancy,
    required this.avgWin,
    required this.avgLoss,
    required this.payoffRatio,
    required this.avgRrPlanned,
    required this.avgRrRealized,
    required this.maxDrawdown,
    required this.maxDrawdownPct,
    required this.longestWinStreak,
    required this.longestLossStreak,
    required this.bySymbol,
    required this.byWeekday,
    required this.bySetup,
    required this.violations,
  });

  factory Summary.fromJson(Json json) {
    final period = map(json['period']);
    final drawdown = map(json['max_drawdown']);

    return Summary(
      from: wallTime('${period['from']}'),
      to: wallTime('${period['to']}'),
      currency: '${json['currency'] ?? 'USD'}',
      initialBalance: toDouble(json['initial_balance']),
      balance: toDouble(json['balance']),
      totalTrades: toInt(json['total_trades']),
      wins: toInt(json['wins']),
      losses: toInt(json['losses']),
      breakeven: toInt(json['breakeven']),
      winRate: toDouble(json['win_rate_pct']),
      netPnl: toDouble(json['net_pnl']),
      profitFactor: toDoubleOrNull(json['profit_factor']),
      expectancy: toDouble(json['expectancy']),
      avgWin: toDouble(json['avg_win']),
      avgLoss: toDouble(json['avg_loss']),
      payoffRatio: toDoubleOrNull(json['payoff_ratio']),
      avgRrPlanned: toDoubleOrNull(json['avg_rr_planned']),
      avgRrRealized: toDoubleOrNull(json['avg_rr_realized']),
      maxDrawdown: toDouble(drawdown['amount']),
      maxDrawdownPct: toDouble(drawdown['pct']),
      longestWinStreak: toInt(json['longest_win_streak']),
      longestLossStreak: toInt(json['longest_loss_streak']),
      bySymbol: _breakdown(json['by_symbol']),
      byWeekday: _breakdown(json['by_weekday']),
      bySetup: _breakdown(json['by_setup']),
      violations: violationsFrom(json['violations']),
    );
  }

  final DateTime from;
  final DateTime to;
  final String currency;
  final double initialBalance;
  final double balance;
  final int totalTrades;
  final int wins;
  final int losses;
  final int breakeven;
  final double winRate;
  final double netPnl;
  final double? profitFactor;
  final double expectancy;
  final double avgWin;
  final double avgLoss;
  final double? payoffRatio;
  final double? avgRrPlanned;
  final double? avgRrRealized;
  final double maxDrawdown;
  final double maxDrawdownPct;
  final int longestWinStreak;
  final int longestLossStreak;
  final Map<String, BreakdownRow> bySymbol;
  final Map<String, BreakdownRow> byWeekday;
  final Map<String, BreakdownRow> bySetup;
  final Map<String, List<String>> violations;
}

/// Posisi hari ini terhadap aturan akun. Murni informatif.
class RuleStatus {
  const RuleStatus({
    required this.pnl,
    required this.trades,
    required this.lossLimit,
    required this.lossUsed,
    required this.lossBreached,
    required this.profitGoal,
    required this.profitReached,
    required this.maxTrades,
    required this.tradesBreached,
    required this.drawdownPct,
    required this.maxDrawdownPct,
    required this.drawdownBreached,
    required this.minRr,
    required this.lowRrTrades,
    required this.hasRules,
  });

  factory RuleStatus.fromJson(Json json) => RuleStatus(
    pnl: toDouble(json['pnl']),
    trades: toInt(json['trades']),
    lossLimit: toDoubleOrNull(json['loss_limit']),
    lossUsed: toDouble(json['loss_used']),
    lossBreached: json['loss_breached'] == true,
    profitGoal: toDoubleOrNull(json['profit_goal']),
    profitReached: json['profit_reached'] == true,
    maxTrades: toIntOrNull(json['max_trades']),
    tradesBreached: json['trades_breached'] == true,
    drawdownPct: toDouble(json['drawdown_pct']),
    maxDrawdownPct: toDoubleOrNull(json['max_drawdown_pct']),
    drawdownBreached: json['drawdown_breached'] == true,
    minRr: toDoubleOrNull(json['min_rr']),
    lowRrTrades: toInt(json['low_rr_trades']),
    hasRules: json['has_rules'] == true,
  );

  final double pnl;
  final int trades;
  final double? lossLimit;
  final double lossUsed;
  final bool lossBreached;
  final double? profitGoal;
  final bool profitReached;
  final int? maxTrades;
  final bool tradesBreached;
  final double drawdownPct;
  final double? maxDrawdownPct;
  final bool drawdownBreached;
  final double? minRr;
  final int lowRrTrades;
  final bool hasRules;

  bool get breached => lossBreached || tradesBreached || drawdownBreached;
}

class EquityPoint {
  const EquityPoint({
    required this.date,
    required this.balance,
    required this.pnl,
    required this.flow,
  });

  factory EquityPoint.fromJson(Json json) => EquityPoint(
    date: wallTime('${json['date']}'),
    balance: toDouble(json['balance']),
    pnl: toDouble(json['pnl']),
    flow: toDouble(json['flow']),
  );

  final DateTime date;
  final double balance;
  final double pnl;

  /// Setoran (+) atau penarikan (−) di hari itu.
  final double flow;
}

class MonthlyPnl {
  const MonthlyPnl({
    required this.month,
    required this.pnl,
    required this.profit,
    required this.loss,
  });

  factory MonthlyPnl.fromJson(Json json) => MonthlyPnl(
    month: '${json['month']}',
    pnl: toDouble(json['pnl']),
    profit: toDouble(json['profit']),
    loss: toDouble(json['loss']),
  );

  /// `2026-03`.
  final String month;
  final double pnl;
  final double profit;
  final double loss;
}

class Dashboard {
  const Dashboard({
    required this.range,
    required this.summary,
    required this.equity,
    required this.monthly,
    required this.monthlyBase,
    required this.ruleStatus,
    required this.recent,
  });

  factory Dashboard.fromJson(Json json) => Dashboard(
    range: '${json['range']}',
    summary: Summary.fromJson(map(json['summary'])),
    equity: list(json['equity'])
        .map((item) => EquityPoint.fromJson(map(item)))
        .toList(),
    monthly: list(json['monthly'])
        .map((item) => MonthlyPnl.fromJson(map(item)))
        .toList(),
    monthlyBase: toDoubleOrNull(json['monthlyBase']),
    ruleStatus: RuleStatus.fromJson(map(json['ruleStatus'])),
    recent: list(json['recent'])
        .map((item) => Trade.fromJson(map(item)))
        .toList(),
  );

  final String range;
  final Summary summary;
  final List<EquityPoint> equity;
  final List<MonthlyPnl> monthly;

  /// Saldo tepat sebelum jendela 12 bulan dimulai — dasar persen grafik bulanan.
  final double? monthlyBase;
  final RuleStatus ruleStatus;
  final List<Trade> recent;

  /// Pertumbuhan periode: P/L dibagi saldo di awal periode, bukan modal + arus
  /// dana — withdrawal tidak boleh membuat persennya naik.
  double get growthPct {
    final base = equity.isEmpty ? 0.0 : equity.first.balance;

    return base > 0 ? summary.netPnl / base * 100 : 0;
  }
}

class DayStat {
  const DayStat({
    required this.pnl,
    required this.trades,
    required this.wins,
    required this.losses,
  });

  factory DayStat.fromJson(Json json) => DayStat(
    pnl: toDouble(json['pnl']),
    trades: toInt(json['trades']),
    wins: toInt(json['wins']),
    losses: toInt(json['losses']),
  );

  final double pnl;
  final int trades;
  final int wins;
  final int losses;
}

class CalendarMonth {
  const CalendarMonth({
    required this.month,
    required this.gridStart,
    required this.gridEnd,
    required this.days,
    required this.violations,
    required this.trades,
    required this.monthTotal,
  });

  factory CalendarMonth.fromJson(Json json) {
    Map<String, DayStat> days(Object? value) =>
        map(value)
            .map((date, stat) => MapEntry(date, DayStat.fromJson(map(stat))));

    return CalendarMonth(
      month: '${json['month']}',
      gridStart: wallTime('${json['gridStart']}'),
      gridEnd: wallTime('${json['gridEnd']}'),
      days: days(json['days']),
      violations: violationsFrom(json['violations']),
      trades: map(json['trades']).map(
        (date, rows) => MapEntry(
          date,
          list(rows).map((item) => Trade.fromJson(map(item))).toList(),
        ),
      ),
      monthTotal: days(json['monthTotal']),
    );
  }

  final String month;
  final DateTime gridStart;
  final DateTime gridEnd;
  final Map<String, DayStat> days;
  final Map<String, List<String>> violations;
  final Map<String, List<Trade>> trades;
  final Map<String, DayStat> monthTotal;
}
