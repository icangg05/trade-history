import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';

/// `GET auth/options` untuk server yang sedang diketik: apakah pendaftaran
/// mandiri dibuka (REGISTER_TOKEN diisi di .env server).
final _canRegisterProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  server,
) async {
  if (server.isEmpty) return false;

  final json = await ApiClient(
    server: server,
    adapter: ref.watch(httpAdapterProvider),
  ).get('auth/options');

  return json['can_register'] == true;
});

class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.subtitle, required this.children});

  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trade History',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 28),
                Panel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _server = TextEditingController(text: ref.read(serverProvider));
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _serverFocus = FocusNode();

  bool _busy = false;
  bool _hidden = true;
  ApiException? _error;

  @override
  void initState() {
    super.initState();

    // Alamat server disimpan begitu kolomnya ditinggalkan, supaya tautan
    // "Daftar" bisa dicek ke server yang benar.
    _serverFocus.addListener(() {
      if (!_serverFocus.hasFocus && _server.text.trim().isNotEmpty) {
        ref.read(serverProvider.notifier).set(_server.text);
      }
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    _serverFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_server.text.trim().isEmpty) {
      setState(
        () => _error = const ApiException(
          'Isi alamat server Trade History kamu dulu.',
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .login(
            server: _server.text,
            email: _email.text.trim(),
            password: _password.text,
          );
    } on ApiException catch (error) {
      // 404 di pintu login berarti alamatnya bukan server Trade History —
      // atau servernya belum diperbarui ke versi yang punya API.
      final shown = error.status == 404
          ? const ApiException(
              'Alamat ini bukan server Trade History, atau servernya belum punya API mobile.',
            )
          : error;

      if (mounted) setState(() => _error = shown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(serverProvider);
    final canRegister = ref.watch(_canRegisterProvider(server)).value ?? false;

    return AuthShell(
      subtitle: 'Masuk ke jurnal trading kamu.',
      children: [
        TextField(
          controller: _server,
          focusNode: _serverFocus,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Alamat server',
            hintText: 'https://trade.contoh.com',
            prefixIcon: const Icon(Icons.dns_outlined, size: 20),
            errorText: _error?.status == null && _error != null
                ? _error!.message
                : null,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.alternate_email, size: 20),
            errorText:
                _error?['email'] ??
                (_error?.status != null && _error!.errors.isEmpty
                    ? _error!.message
                    : null),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _hidden,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Kata sandi',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            errorText: _error?['password'],
            suffixIcon: IconButton(
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
        const SizedBox(height: 20),
        BusyButton(
          busy: _busy,
          onPressed: _submit,
          label: 'Masuk',
          icon: Icons.login,
        ),
        if (canRegister) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Belum punya akun? Daftar'),
          ),
        ],
      ],
    );
  }
}
