import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/session.dart';
import '../models/account.dart';
import 'common.dart';
import 'user_avatar.dart';

/// Kerangka layar yang butuh akun aktif: judul + pengalih akun di app bar,
/// dan pesan "buat akun dulu" kalau belum ada satu pun — padanan middleware
/// `RequireAccount` di web.
class AccountScaffold extends ConsumerWidget {
  const AccountScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.loading,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget Function(BuildContext context, AccountBrief account) body;

  /// Kerangka layar ini selama akun aktif belum diketahui — sama dengan
  /// kerangka isinya, jadi tidak berganti bentuk di tengah jalan.
  final Widget loading;
  final List<Widget> Function(AccountBrief account)? actions;
  final Widget? Function(AccountBrief account)? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAccountProvider);
    final account = current.value;
    // Layar utama tab: foto profil di kiri. Layar turunan (aturan, analisa)
    // tetap memakai tombol kembali di tempat itu.
    final root = !(ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      appBar: AppBar(
        leading: root ? const HeaderAvatar() : null,
        titleSpacing: root ? 4 : 16,
        title: AccountSwitcher(title: title),
        actions: account == null
            ? null
            : [...?actions?.call(account), const SizedBox(width: 4)],
      ),
      floatingActionButton: account == null
          ? null
          : floatingActionButton?.call(account),
      body: current.when(
        skipLoadingOnReload: true,
        loading: () => loading,
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(meProvider)),
        data: (account) =>
            account == null ? const NoAccount() : body(context, account),
      ),
    );
  }
}

/// Judul layar dengan nama akun aktif di bawahnya; diketuk untuk berganti akun.
class AccountSwitcher extends ConsumerWidget {
  const AccountSwitcher({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider).value;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: account == null ? null : () => showAccountPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (account != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      account.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAccountPicker(
  BuildContext context,
  WidgetRef ref,
) => showModalBottomSheet<void>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  builder: (sheet) => Consumer(
    builder: (context, ref, _) {
      final me = ref.watch(meProvider).value;
      final current = ref.watch(currentAccountProvider).value;

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Akun trading',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            // Daftarnya digulir sendiri, judul dan "Kelola akun" tetap:
            // dengan lima akun lebih, isinya melebihi tinggi lembar ini.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final account in me?.accounts ?? const <AccountBrief>[])
                    ListTile(
                      // `selected` juga diumumkan pembaca layar; tanda
                      // centang, bukan hanya warna, menandai akun aktif.
                      selected: account.id == current?.id,
                      selectedColor: AppColors.gold,
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(account.name),
                      subtitle: Text(
                        '${account.broker ?? 'Tanpa broker'} · ${account.currency}',
                      ),
                      trailing: account.id == current?.id
                          ? const Icon(Icons.check, color: AppColors.gold)
                          : null,
                      onTap: () {
                        ref
                            .read(selectedAccountProvider.notifier)
                            .select(account.id);
                        Navigator.pop(sheet);
                      },
                    ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Kelola akun'),
              onTap: () {
                Navigator.pop(sheet);
                context.go('/more/accounts');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  ),
);

class NoAccount extends StatelessWidget {
  const NoAccount({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      message: 'Buat satu akun trading dulu untuk mulai mencatat.',
      action: FilledButton.icon(
        onPressed: () => context.go('/more/accounts'),
        icon: const Icon(Icons.add),
        label: const Text('Buat akun'),
      ),
    ),
  );
}
