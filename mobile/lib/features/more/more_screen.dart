import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/user_avatar.dart';

/// Menu "Lainnya": halaman yang tidak muat di tab bar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final server = ref.watch(sessionProvider).value?.server ?? '';

    Widget item(IconData icon, String title, String subtitle, String path) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.mutedForeground,
          ),
          onTap: () => context.go(path),
        );

    return Scaffold(
      appBar: AppBar(
        leading: const HeaderAvatar(),
        titleSpacing: 4,
        title: const Text('Lainnya'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (me != null)
            Panel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Foto profil',
                    padding: EdgeInsets.zero,
                    onPressed: () => showAvatarSheet(context),
                    icon: const UserAvatar(radius: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Caption(me.user.email),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                item(
                  Icons.rule_outlined,
                  'Aturan trading',
                  'Batas harian, risiko, sesi, catatan',
                  '/more/rules',
                ),
                item(
                  Icons.auto_awesome_outlined,
                  'Analisa',
                  'Statistik periode dan analisa AI',
                  '/more/analysis',
                ),
                item(
                  Icons.picture_as_pdf_outlined,
                  'Laporan tahunan',
                  'PDF untuk keperluan pajak',
                  '/more/reports',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                item(
                  Icons.account_balance_wallet_outlined,
                  'Akun trading',
                  'Buat, ubah, arsipkan akun',
                  '/more/accounts',
                ),
                item(
                  Icons.person_outline,
                  'Profil',
                  'Nama, email, kata sandi',
                  '/more/profile',
                ),
                item(
                  Icons.devices_outlined,
                  'Perangkat',
                  'Ponsel yang sedang masuk ke akun ini',
                  '/more/devices',
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.destructive,
                  ),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                  onTap: () async {
                    if (await confirm(
                      context,
                      title: 'Keluar dari perangkat ini?',
                      action: 'Keluar',
                    )) {
                      await ref.read(sessionProvider.notifier).logout();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Caption('Terhubung ke $server')),
        ],
      ),
    );
  }
}
