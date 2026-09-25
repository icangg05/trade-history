import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../data/journal_api.dart';
import '../data/session.dart';
import 'avatar_cropper.dart';
import 'common.dart';

/// Foto profil bulat; inisial nama selama belum ada foto atau fotonya gagal dimuat.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.radius = 17});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(meProvider).value?.user;
    final version = user?.avatar;
    final name = user?.name ?? '';
    final api = ref.watch(journalProvider);

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold.withValues(alpha: .15),
      foregroundColor: AppColors.gold,
      foregroundImage: version == null
          ? null
          : NetworkImage(
              api.avatarUrl(version),
              headers: api.client.imageHeaders,
            ),
      // Gagal dimuat → inisialnya tetap tampil di bawah.
      onForegroundImageError: version == null ? null : (_, _) {},
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * .8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Foto profil di ujung kiri app bar layar utama; diketuk untuk menggantinya.
class HeaderAvatar extends ConsumerWidget {
  const HeaderAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Foto profil',
    onPressed: () => showAvatarSheet(context),
    icon: const UserAvatar(),
  );
}

Future<void> showAvatarSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      // Menutupi tab bar juga, sama seperti modal di web.
      useRootNavigator: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final user = ref.watch(meProvider).value?.user;

          void pick(ImageSource source) {
            Navigator.pop(sheet);
            _change(context, source);
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const UserAvatar(radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Caption(user?.email ?? ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => pick(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Ambil foto'),
                  onTap: () => pick(ImageSource.camera),
                ),
                if (user?.avatar != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.destructive,
                    ),
                    title: const Text(
                      'Hapus foto',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                    onTap: () {
                      Navigator.pop(sheet);
                      _save(context, (api) => api.deleteAvatar());
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profil'),
                  onTap: () {
                    Navigator.pop(sheet);
                    context.go('/more/profile');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

/// Pilih → potong → unggah. Fotonya diambil cukup besar supaya masih tajam
/// saat di-zoom di layar potong; yang diunggah hanya hasil potongannya
/// (512 px), dan server tetap menormalkannya lagi.
Future<void> _change(BuildContext context, ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 90,
    preferredCameraDevice: CameraDevice.front,
  );

  if (file == null) return;

  final bytes = await file.readAsBytes();

  if (!context.mounted) return;

  final cropped = await cropAvatar(context, bytes);

  if (cropped == null || !context.mounted) return;

  showMessage(context, 'Mengunggah foto…');
  await _save(
    context,
    (api) => api.uploadAvatar(
      XFile.fromData(cropped, name: 'avatar.png', mimeType: 'image/png'),
    ),
  );
}

/// Kontainer, bukan `ref` milik widget: unggahan tetap selesai walau layar
/// yang memulainya sudah ditinggalkan.
Future<void> _save(
  BuildContext context,
  Future<String> Function(JournalApi api) send,
) async {
  final container = ProviderScope.containerOf(context, listen: false);

  try {
    final message = await send(container.read(journalProvider));

    container.invalidate(meProvider);
    if (context.mounted) showMessage(context, message);
  } on ApiException catch (error) {
    if (context.mounted) showMessage(context, error.message, error: true);
  }
}
