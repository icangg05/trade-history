import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';

const _canRegisterKey = 'auth.can_register';

/// `GET auth/options`: apakah pendaftaran mandiri dibuka (REGISTER_TOKEN diisi
/// di .env server). Sengaja tidak autoDispose — layar login dibuang saat pindah
/// ke layar daftar, dan tanpa cache ini tautan "Daftar" baru muncul setelah
/// server menjawab lagi. Jawabannya juga disimpan di ponsel (lihat
/// [LoginScreen]).
final canRegisterProvider = FutureProvider<bool>((ref) async {
  final server = ref.watch(serverProvider);

  if (server.isEmpty) return false;

  final json = await ApiClient(
    server: server,
    adapter: ref.watch(httpAdapterProvider),
  ).get('auth/options');
  final open = json['can_register'] == true;

  await ref.read(prefsProvider).setBool(_canRegisterKey, open);

  return open;
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

/// Ikon mata di kolom kata sandi. Berlabel, supaya pembaca layar tidak
/// hanya menyebut "tombol".
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    super.key,
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: hidden ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
    icon: Icon(
      hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 20,
    ),
    onPressed: onPressed,
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _hidden = true;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final server = ref.read(serverProvider);

    if (server.isEmpty) {
      setState(
        () => _error = const ApiException(
          'Aplikasi ini dibangun tanpa alamat server. Build ulang dengan '
          '--dart-define=API_BASE_URL=https://alamat-server-kamu.',
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
            server: server,
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
    // Jawaban terakhir yang tersimpan tampil seketika; jawaban baru dari
    // server menyusul. Tanpa ini tautan "Daftar" selalu muncul terlambat.
    final canRegister =
        ref.watch(canRegisterProvider).value ??
        ref.watch(prefsProvider).getBool(_canRegisterKey) ??
        false;

    return AuthShell(
      subtitle: 'Masuk ke jurnal trading kamu.',
      children: [
        TextField(
          controller: _email,
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
        TextField(
          controller: _password,
          obscureText: _hidden,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Kata sandi',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            errorText: _error?['password'],
            suffixIcon: PasswordToggle(
              hidden: _hidden,
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Galat tanpa kolom: server tak terjangkau, alamat build salah, dsb.
        if (_error != null && _error!.errors.isEmpty) ...[
          Text(
            _error!.message,
            style: const TextStyle(
              color: AppColors.destructive,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
        ],
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
