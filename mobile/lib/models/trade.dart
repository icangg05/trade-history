import '../core/format.dart';
import '../core/json.dart';

/// Posisi stop loss terhadap entry — lihat `Trade::stopState()` di server.
enum StopState {
  /// Masih di sisi rugi: R bisa dihitung.
  risk,

  /// Persis di harga entry: risiko nol.
  breakeven,

  /// Sudah melewati entry: profit terkunci (SL+).
  locked;

  static StopState? parse(Object? value) => switch (value) {
    'risk' => risk,
    'breakeven' => breakeven,
    'locked' => locked,
    _ => null,
  };
}

class Trade {
  const Trade({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.status,
    required this.pnl,
    required this.openedAt,
    this.setup,
    this.groupId,
    this.notes,
    this.source = 'manual',
    this.lot,
    this.entryPrice,
    this.slPrice,
    this.tpPrice,
    this.exitPrice,
    this.stopState,
    this.rrPlanned,
    this.rrRealized,
    this.closedAt,
    this.aiRaw,
  });

  /// Dashboard, kalender, dan daftar trade mengirim bentuk yang sedikit
  /// berbeda; kolom yang tidak dikirim dibiarkan null.
  factory Trade.fromJson(Json json) => Trade(
    id: '${json['id']}',
    symbol: '${json['symbol'] ?? ''}',
    direction: '${json['direction'] ?? 'buy'}',
    status: '${json['status'] ?? 'be'}',
    setup: toStringOrNull(json['setup']),
    groupId: toStringOrNull(json['group_id']),
    notes: toStringOrNull(json['notes']),
    source: '${json['source'] ?? 'manual'}',
    lot: toDoubleOrNull(json['lot']),
    entryPrice: toDoubleOrNull(json['entry_price']),
    slPrice: toDoubleOrNull(json['sl_price']),
    tpPrice: toDoubleOrNull(json['tp_price']),
    exitPrice: toDoubleOrNull(json['exit_price']),
    pnl: toDouble(json['pnl']),
    stopState: StopState.parse(json['stop_state']),
    rrPlanned: toDoubleOrNull(json['rr_planned']),
    rrRealized: toDoubleOrNull(json['rr_realized']),
    openedAt: wallTime('${json['opened_at']}'),
    closedAt: wallTimeOrNull(json['closed_at']),
    aiRaw: json['ai_raw'] is Map ? map(json['ai_raw']) : null,
  );

  /// Hash dari server (lihat `App\Support\Hashid`) — bukan angka urut.
  final String id;
  final String symbol;

  /// `buy` atau `sell`.
  final String direction;

  /// `win`, `loss`, atau `be`.
  final String status;
  final String? setup;

  /// Kunci grup: beberapa trade berurutan yang lahir dari satu ide.
  final String? groupId;
  final String? notes;

  /// `manual` atau `ai` (diisi dari screenshot).
  final String source;
  final double? lot;
  final double? entryPrice;
  final double? slPrice;
  final double? tpPrice;
  final double? exitPrice;
  final double pnl;
  final StopState? stopState;
  final double? rrPlanned;
  final double? rrRealized;
  final DateTime openedAt;
  final DateTime? closedAt;
  final Json? aiRaw;

  bool get isBuy => direction == 'buy';

  /// Hari efektif trade: hari ia ditutup, sama seperti `COALESCE(closed_at, opened_at)`.
  DateTime get day => closedAt ?? openedAt;

  String get dayKey => isoDate(day);

  List<String> get setups => (setup ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

/// Filter `/trades`. Record, supaya dua filter yang isinya sama dianggap sama
/// dan provider-nya tidak memuat ulang.
typedef TradeFilters = ({
  String symbol,
  String setup,
  String q,
  String status,
  String stop,
  String direction,
  String from,
  String to,
});

const TradeFilters noTradeFilters = (
  symbol: '',
  setup: '',
  q: '',
  status: '',
  stop: '',
  direction: '',
  from: '',
  to: '',
);

extension TradeFiltersX on TradeFilters {
  Map<String, dynamic> toQuery() => {
    'symbol': symbol,
    'setup': setup,
    'q': q,
    'status': status,
    'stop': stop,
    'direction': direction,
    'from': from,
    'to': to,
  };

  int get active =>
      toQuery().values.where((value) => '$value'.isNotEmpty).length;
}

/// Satu halaman `/trades`: 25 trade + P/L per hari yang dihitung server,
/// supaya total harian tetap utuh walau harinya terpotong batas halaman.
class TradePage {
  const TradePage({
    required this.items,
    required this.daily,
    required this.symbols,
    required this.setups,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  factory TradePage.fromJson(Json json) {
    final trades = map(json['trades']);

    return TradePage(
      items: list(trades['data'])
          .map((item) => Trade.fromJson(map(item)))
          .toList(),
      daily: map(json['daily'])
          .map((key, value) => MapEntry(key, toDouble(value))),
      symbols: strings(json['symbols']),
      setups: strings(json['setups']),
      page: toInt(trades['current_page']),
      lastPage: toInt(trades['last_page']),
      total: toInt(trades['total']),
    );
  }

  final List<Trade> items;
  final Map<String, double> daily;
  final List<String> symbols;
  final List<String> setups;
  final int page;
  final int lastPage;
  final int total;
}

/// Hasil baca screenshot oleh Gemini, siap mengisi form.
class ExtractResult {
  const ExtractResult({
    required this.data,
    required this.lowConfidence,
    required this.raw,
  });

  factory ExtractResult.fromJson(Json json) => ExtractResult(
    data: map(json['data']),
    lowConfidence: strings(json['low_confidence_fields']),
    raw: json['raw'] is Map ? map(json['raw']) : null,
  );

  final Json data;
  final List<String> lowConfidence;
  final Json? raw;
}
