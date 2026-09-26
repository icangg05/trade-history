import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Lupa sandi: email → kode 4 digit dari email, dicek dulu → baru form sandi
/// baru. Berhasil berarti langsung masuk; semua perangkat lain dikeluarkan server.
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _busy = false;
  bool _hidden = true;

  /// Pesan server setelah kode dikirim; null selama masih di langkah email.
  String? _sent;

  /// Kode sudah dicek server: kolom kode diganti form sandi baru.
  bool _verified = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      // Kode ditolak saat ganti sandi (kedaluwarsa selagi sandi diisi):
      // kembali ke langkah kode, tempat galatnya tampil dan kode baru diminta.
      setState(() {
        _error = error;
        if (error['code'] != null) _verified = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    final message = await ref
        .read(sessionProvider.notifier)
        .requestResetCode(_email.text.trim());

    if (mounted) setState(() => _sent = message);
  });

  Future<void> _verify() => _run(() async {
    await ref
        .read(sessionProvider.notifier)
        .verifyResetCode(_email.text.trim(), _code.text);

    if (mounted) setState(() => _verified = true);
  });

  Future<void> _reset() => _run(
    () => ref
        .read(sessionProvider.notifier)
        .resetPassword(
          email: _email.text.trim(),
          code: _code.text,
          password: _password.text,
          passwordConfirmation: _confirmation.text,
        ),
  );

  Widget _secret(TextEditingController controller, String label, String key) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          obscureText: _hidden,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: label,
            errorText: _error?[key],
            suffixIcon: PasswordToggle(
              hidden: _hidden,
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AuthShell(
    subtitle: 'Buat kata sandi baru.',
    children: [
      TextField(
        controller: _email,
        // Email dikunci setelah kode dikirim: kodenya milik email itu.
        enabled: _sent == null,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: 'Email',
          prefixIcon: const Icon(Icons.alternate_email, size: 20),
          errorText: _error?['email'],
        ),
      ),
      const SizedBox(height: 14),
      if (_sent == null)
        const Caption('Kode 4 digit akan dikirim ke email ini.')
      else if (!_verified) ...[
        Notice(icon: Icons.mark_email_read_outlined, child: Text(_sent!)),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          style: mono(size: 18, weight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Kode dari email',
            counterText: '',
            errorText: _error?['code'],
          ),
        ),
      ] else ...[
        const Notice(
          icon: Icons.verified_user_outlined,
          color: AppColors.success,
          child: Text('Kode benar. Sekarang buat kata sandi baru.'),
        ),
        const SizedBox(height: 14),
        _secret(_password, 'Kata sandi baru (min. 8 karakter)', 'password'),
        _secret(
          _confirmation,
          'Ulangi kata sandi baru',
          'password_confirmation',
        ),
      ],
      const SizedBox(height: 6),
      // Galat tanpa kolom: server tak terjangkau, terlalu banyak permintaan.
      if (_error != null && _error!.errors.isEmpty) ...[
        Text(
          _error!.message,
          style: const TextStyle(color: AppColors.destructive, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
      ],
      if (_sent == null)
        BusyButton(
          busy: _busy,
          onPressed: _send,
          label: 'Kirim kode',
          icon: Icons.send_outlined,
        )
      else if (!_verified) ...[
        BusyButton(
          busy: _busy,
          onPressed: _verify,
          label: 'Verifikasi',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : _send,
          child: const Text('Kirim ulang kode'),
        ),
      ] else
        BusyButton(
          busy: _busy,
          onPressed: _reset,
          label: 'Ganti sandi',
          icon: Icons.lock_reset,
        ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Kembali ke halaman masuk'),
      ),
    ],
  );
}
