import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Pendaftaran mandiri — hanya terbuka kalau server mengisi REGISTER_TOKEN,
/// dan tokennya harus diketahui pendaftar.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _token = TextEditingController();

  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirmation,
      _token,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            server: ref.read(serverProvider),
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            passwordConfirmation: _confirmation.text,
            token: _token.text.trim(),
          );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool secret = false,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: secret,
      keyboardType: type,
      autocorrect: false,
      decoration: InputDecoration(labelText: label, errorText: _error?[key]),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthShell(
    subtitle: 'Buat akun untuk mulai mencatat.',
    children: [
      Caption('Server: ${ref.watch(serverProvider)}'),
      const SizedBox(height: 14),
      _field(_name, 'Nama', 'name'),
      _field(_email, 'Email', 'email', type: TextInputType.emailAddress),
      _field(
        _password,
        'Kata sandi (min. 8 karakter)',
        'password',
        secret: true,
      ),
      _field(
        _confirmation,
        'Ulangi kata sandi',
        'password_confirmation',
        secret: true,
      ),
      _field(_token, 'Token pendaftaran', 'token'),
      if (_error != null && _error!.errors.isEmpty) ...[
        Text(
          _error!.message,
          style: const TextStyle(color: AppColors.destructive, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
      ],
      BusyButton(
        busy: _busy,
        onPressed: _submit,
        label: 'Daftar',
        icon: Icons.person_add_alt,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Sudah punya akun? Masuk'),
      ),
    ],
  );
}
