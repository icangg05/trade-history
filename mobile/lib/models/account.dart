import '../core/format.dart';
import '../core/json.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });

  factory User.fromJson(Json json) => User(
    id: toInt(json['id']),
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    avatar: toStringOrNull(json['avatar']),
  );

  final int id;
  final String name;
  final String email;

  /// Versi foto profil, null kalau belum ada foto (lihat `avatarUrl`).
  final String? avatar;
}

/// Akun trading yang bisa dibuka — isi pengalih akun.
class AccountBrief {
  const AccountBrief({
    required this.id,
    required this.name,
    required this.broker,
    required this.currency,
    required this.startedAt,
  });

  factory AccountBrief.fromJson(Json json) => AccountBrief(
    id: toInt(json['id']),
    name: '${json['name'] ?? ''}',
    broker: toStringOrNull(json['broker']),
    currency: '${json['currency'] ?? 'USD'}',
    startedAt: wallTimeOrNull(json['started_at']),
  );

  final int id;
  final String name;
  final String? broker;
  final String currency;
  final DateTime? startedAt;
}

/// `GET /me`: pemegang token dan akun yang tidak diarsipkan.
class Me {
  const Me({required this.user, required this.accounts});

  factory Me.fromJson(Json json) => Me(
    user: User.fromJson(map(json['user'])),
    accounts: list(json['accounts'])
        .map((item) => AccountBrief.fromJson(map(item)))
        .toList(),
  );

  final User user;
  final List<AccountBrief> accounts;
}

/// Satu kartu di halaman akun.
class AccountRow {
  const AccountRow({
    required this.id,
    required this.name,
    required this.broker,
    required this.accountNumber,
    required this.currency,
    required this.isArchived,
    required this.startedAt,
    required this.balance,
    required this.netPnl,
    required this.trades,
  });

  factory AccountRow.fromJson(Json json) => AccountRow(
    id: toInt(json['id']),
    name: '${json['name'] ?? ''}',
    broker: toStringOrNull(json['broker']),
    accountNumber: toStringOrNull(json['account_number']),
    currency: '${json['currency'] ?? 'USD'}',
    isArchived: json['is_archived'] == true,
    startedAt: wallTime('${json['started_at']}'),
    balance: toDouble(json['balance']),
    netPnl: toDouble(json['net_pnl']),
    trades: toInt(json['trades']),
  );

  final int id;
  final String name;
  final String? broker;
  final String? accountNumber;
  final String currency;
  final bool isArchived;
  final DateTime startedAt;
  final double balance;
  final double netPnl;
  final int trades;
}

/// Jumlah seluruh akun per mata uang — USD, USC, dan IDR tidak pernah dijumlah jadi satu.
class AccountTotal {
  const AccountTotal({
    required this.currency,
    required this.accounts,
    required this.balance,
    required this.netPnl,
    required this.trades,
  });

  factory AccountTotal.fromJson(Json json) => AccountTotal(
    currency: '${json['currency'] ?? 'USD'}',
    accounts: toInt(json['accounts']),
    balance: toDouble(json['balance']),
    netPnl: toDouble(json['net_pnl']),
    trades: toInt(json['trades']),
  );

  final String currency;
  final int accounts;
  final double balance;
  final double netPnl;
  final int trades;
}

class AccountsPage {
  const AccountsPage({required this.items, required this.totals});

  factory AccountsPage.fromJson(Json json) => AccountsPage(
    items: list(json['items'])
        .map((item) => AccountRow.fromJson(map(item)))
        .toList(),
    totals: list(json['totals'])
        .map((item) => AccountTotal.fromJson(map(item)))
        .toList(),
  );

  final List<AccountRow> items;
  final List<AccountTotal> totals;
}
