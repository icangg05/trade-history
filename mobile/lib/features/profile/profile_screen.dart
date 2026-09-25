import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';

final _profileProvider = FutureProvider.autoDispose<Json>(
  (ref) => ref.watch(journalProvider).profile(),
);

/// Keterangan, form data login (lima isian + tombol), lalu kartu hapus akun.
const _loading = SkeletonView(
  children: [
    Bone(width: 120, height: 10),
    Panel(child: SkeletonFields(count: 6)),
    Panel(child: SkeletonLines(lines: 3)),
  ],
);

/// Nama, email, kata sandi. Mengganti email atau sandi meminta sandi sekarang;
/// sandi baru mencabut token di perangkat lain (sesi ini tetap masuk).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Profil')),
    body: AsyncView(
      value: ref.watch(_profileProvider),
      onRetry: () => ref.invalidate(_profileProvider),
      loading: _loading,
      builder: (json) => _ProfileForm(
        user: map(json['user']),
        accountCount: toInt(json['accountCount']),
      ),
    ),
  );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user, required this.accountCount});

  final Json user;
  final int accountCount;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController(
    text: '${widget.user['name'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.user['email'] ?? ''}',
  );
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _current = TextEditingController();

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirmation,
      _current,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    try {
      // Kolom sandi yang kosong tidak dikirim sama sekali: ganti nama saja
      // tidak perlu membuktikan sandi sekarang.
      final message = await ref.read(journalProvider).updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
        if (_password.text.isNotEmpty)
          'password_confirmation': _confirmation.text,
        if (_current.text.isNotEmpty) 'current_password': _current.text,
      });

      ref.invalidate(meProvider);
      _password.clear();
      _confirmation.clear();
      _current.clear();

      if (mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = error.errors);
        if (error.errors.isEmpty) {
          showMessage(context, error.message, error: true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _destroy() async {
    // Teks biasa, bukan TextEditingController — lihat `confirmWithCode`.
    var typed = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Konten digulir bila keyboard + layar miring menyisakan sedikit
        // tinggi.
        scrollable: true,
        title: const Text('Yakin hapus akun?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Semua data hilang permanen. Masukkan kata sandi untuk melanjutkan.',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => typed = value,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Kata sandi'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructiveFill,
              foregroundColor: AppColors.destructiveForeground,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(journalProvider).deleteProfile(typed);
      await ref.read(sessionProvider.notifier).forget();
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error['password'] ?? error.message, error: true);
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool secret = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: secret,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: _errors[key],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
    children: [
      const Caption('Data login kamu.'),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_name, 'Nama', 'name'),
            _field(_email, 'Email', 'email'),
            _field(
              _current,
              'Kata sandi sekarang',
              'current_password',
              secret: true,
              hint: 'Wajib saat mengganti email atau kata sandi',
            ),
            _field(
              _password,
              'Kata sandi baru',
              'password',
              secret: true,
              hint: 'Kosongkan bila tidak diganti',
            ),
            _field(
              _confirmation,
              'Ulangi kata sandi baru',
              'password_confirmation',
              secret: true,
            ),
            BusyButton(
              busy: _busy,
              onPressed: _save,
              label: 'Simpan profil',
              icon: Icons.check,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Panel(
        borderColor: AppColors.destructive.withValues(alpha: .4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.destructive,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Hapus akun',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.destructive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Caption(
              'Menghapus akun ini juga menghapus ${widget.accountCount} akun trading beserta seluruh trade, '
              'transaksi, bukti transfer, aturan, dan analisanya. Tidak bisa dibatalkan.',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive),
                ),
                onPressed: _destroy,
                child: const Text('Hapus akun saya'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
