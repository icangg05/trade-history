import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

final _devicesProvider = FutureProvider.autoDispose<List<Device>>(
  (ref) => ref.watch(journalProvider).devices(),
);

const _loading = SkeletonView(
  children: [Bone(width: 240, height: 10), SkeletonRows(count: 2)],
);

/// Ponsel yang sedang masuk ke akun ini. Yang hilang atau bukan milik sendiri
/// bisa dikeluarkan dari sini tanpa mengganti sandi.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    if (!await confirm(
      context,
      title: 'Keluarkan ${device.name}?',
      message:
          'Perangkat itu harus masuk lagi dengan sandi untuk membuka akun ini.',
      action: 'Keluarkan',
      destructive: true,
    )) {
      return;
    }

    try {
      final message = await ref.read(journalProvider).revokeDevice(device.id);

      ref.invalidate(_devicesProvider);
      if (context.mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (context.mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Perangkat')),
    body: AsyncView(
      value: ref.watch(_devicesProvider),
      onRetry: () => ref.invalidate(_devicesProvider),
      loading: _loading,
      builder: (devices) => RefreshIndicator(
        onRefresh: () => ref.refresh(_devicesProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Caption(
              'Perangkat yang 30 hari tidak dipakai keluar dengan sendirinya.',
            ),
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final device in devices)
                    ListTile(
                      leading: Icon(switch (device.name) {
                        'Android' => Icons.phone_android,
                        'iPhone / iPad' => Icons.phone_iphone,
                        _ => Icons.devices_other,
                      }),
                      title: Text(
                        device.current
                            ? '${device.name} · perangkat ini'
                            : device.name,
                      ),
                      subtitle: Text(
                        'Aktif ${shortDateTime(device.lastUsedAt)}\n'
                        'Masuk ${longDate(device.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: device.current
                          ? null
                          : TextButton(
                              onPressed: () => _revoke(context, ref, device),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                              ),
                              child: const Text('Keluarkan'),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
