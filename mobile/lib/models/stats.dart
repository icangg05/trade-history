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
    required this.balance,
    required this.totalDeposited,
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.winRate,
    required this.netPnl,
    required this.grossProfit,
    required this.grossLoss,
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
      balance: toDouble(json['balance']),
      totalDeposited: toDouble(json['total_deposited']),
      totalTrades: toInt(json['total_trades']),
      wins: toInt(json['wins']),
      losses: toInt(json['losses']),
      breakeven: toInt(json['breakeven']),
      winRate: toDouble(json['win_rate_pct']),
      netPnl: toDouble(json['net_pnl']),
      grossProfit: toDouble(json['gross_profit']),
      grossLoss: toDouble(json['gross_loss']),
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
  final double balance;

  /// Semua deposit: seluruh uang yang pernah disetor.
  final double totalDeposited;
  final int totalTrades;
  final int wins;
  final int losses;
  final int breakeven;
  final double winRate;
  final double netPnl;
  final double grossProfit;

  /// Positif: jumlah kerugian trade yang kalah, tanpa tanda.
  final double grossLoss;
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
    required this.drawdown,
    required this.maxDrawdown,
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
    drawdown: toDouble(json['drawdown']),
    maxDrawdown: toDoubleOrNull(json['max_drawdown']),
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

  /// Turun dari puncak kurva trading, dalam nilai mata uang.
  final double drawdown;
  final double? maxDrawdown;
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

class Dashboard {
  const Dashboard({
    required this.range,
    required this.summary,
    required this.equity,
    required this.ruleStatus,
    required this.recent,
  });

  factory Dashboard.fromJson(Json json) => Dashboard(
    range: '${json['range']}',
    summary: Summary.fromJson(map(json['summary'])),
    equity: list(json['equity'])
        .map((item) => EquityPoint.fromJson(map(item)))
        .toList(),
    ruleStatus: RuleStatus.fromJson(map(json['ruleStatus'])),
    recent: list(json['recent'])
        .map((item) => Trade.fromJson(map(item)))
        .toList(),
  );

  final String range;
  final Summary summary;
  final List<EquityPoint> equity;
  final RuleStatus ruleStatus;
  final List<Trade> recent;

  /// Pertumbuhan periode; null kalau tidak ada modal yang bisa dijadikan dasar.
  double? get growthPct => periodGrowth(equity, summary.netPnl);
}

/// Pertumbuhan periode: P/L dibagi semua uang yang dipakai, yaitu saldo di
/// awal periode ditambah deposit selama periode. Withdrawal sengaja tidak
/// mengurangi dasarnya: profit yang rutin ditarik akan menyusutkan dasar itu
/// sampai persennya meledak ke ribuan (itu kelemahan Modified Dietz, yang
/// sempat dipakai di sini).
///
/// Saldo awal diambil sebelum hari pertama bergerak, jadi trade di hari
/// pertama periode tidak ikut jadi modal.
double? periodGrowth(List<EquityPoint> points, double pnl) {
  if (points.isEmpty) return null;

  final first = points.first;
  var base = first.balance - first.pnl - first.flow;

  for (final point in points) {
    if (point.flow > 0) base += point.flow;
  }

  return base > 0 ? pnl / base * 100 : null;
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
