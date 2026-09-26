import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/session.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/analysis/chat_screen.dart';
import 'features/auth/forgot_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/more/more_screen.dart';
import 'features/profile/devices_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/reports/report_screen.dart';
import 'features/rules/rules_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/trades/trade_form_screen.dart';
import 'features/trades/trades_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'widgets/backdrop.dart';

class TradeHistoryApp extends ConsumerWidget {
  const TradeHistoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Trade History',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    darkTheme: buildTheme(),
    themeMode: ThemeMode.dark,
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
}

final _rootKey = GlobalKey<NavigatorState>();

/// Halaman dengan transisi Material. go_router 18 hanya mengenali MaterialApp
/// milik `package:material_ui`, sedangkan aplikasi ini masih memakai
/// `package:flutter/material.dart` (fl_chart & kawan-kawan belum pindah) —
/// tanpa ini semua perpindahan layar tampil tanpa animasi.
///
/// Latarnya dilukis per halaman, bukan sekali di belakang aplikasi: tiap
/// halaman jadi buram sendiri, jadi saat transisi halaman lama tidak tembus
/// ke halaman baru.
GoRouterPageBuilder _page(Widget Function(GoRouterState state) child) =>
    (context, state) => MaterialPage<void>(
      key: state.pageKey,
      name: state.name,
      child: Backdrop(child: _Readable(child: child(state))),
    );

/// Di tablet isi halaman dibatasi 840 dp di tengah, latarnya tetap selebar
/// layar: daftar, form, dan kartu yang direntang 1.300 dp sulit dibaca dan
/// kotak isiannya jadi selebar layar. Di ponsel tidak berpengaruh.
class _Readable extends StatelessWidget {
  const _Readable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: child,
    ),
  );
}

/// Form trade naik dari bawah seperti lembar isian, bukan bergeser seperti
/// halaman biasa: tandanya "isi lalu tutup", dan tombol kiri atasnya jadi ✕.
/// Pengguna yang mematikan animasi di ponsel langsung melihat formnya.
GoRouterPageBuilder _formPage(Widget Function(GoRouterState state) child) =>
    _slidePage(child, from: const Offset(0, 1), dialog: true);

/// Halaman yang meluncur masuk dari [from] — form dari bawah, chat dari
/// kanan seperti Lainnya — dengan bayangan di tepi depannya.
GoRouterPageBuilder _slidePage(
  Widget Function(GoRouterState state) child, {
  Offset from = const Offset(1, 0),
  bool dialog = false,
}) =>
    (context, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      fullscreenDialog: dialog,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      child: Backdrop(child: _Readable(child: child(state))),
      transitionsBuilder: (context, animation, _, page) =>
          MediaQuery.disableAnimationsOf(context)
          ? page
          : SlideTransition(
              position: Tween(begin: from, end: Offset.zero).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Color(0x73000000), blurRadius: 24),
                  ],
                ),
                child: page,
              ),
            ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);

  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final atAuth = const [
        '/login',
        '/register',
        '/forgot',
      ].contains(location);

      if (!session.hasValue) return location == '/splash' ? null : '/splash';

      if (session.value == null) {
        // Sekali saja, di pemasangan baru. Yang pernah masuk sudah ditandai.
        if (ref.read(prefsProvider).getBool(onboardedKey) != true) {
          return location == '/welcome' ? null : '/welcome';
        }

        return atAuth ? null : '/login';
      }

      return atAuth || location == '/splash' || location == '/welcome'
          ? '/'
          : null;
    },
    errorBuilder: (context, state) => Backdrop(
      child: Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
      ),
    ),
    routes: [
      GoRoute(path: '/splash', pageBuilder: _page((_) => const _Splash())),
      GoRoute(
        path: '/welcome',
        pageBuilder: _page((_) => const WelcomeScreen()),
      ),
      GoRoute(path: '/login', pageBuilder: _page((_) => const LoginScreen())),
      GoRoute(
        path: '/register',
        pageBuilder: _page((_) => const RegisterScreen()),
      ),
      GoRoute(path: '/forgot', pageBuilder: _page((_) => const ForgotScreen())),
      StatefulShellRoute(
        builder: (context, state, shell) => HomeShell(shell: shell),
        // Sama dengan `indexedStack` bawaan, ditambah HeroMode. Tab yang
        // tidak aktif tetap hidup di latar; tanpa ini FAB-nya ikut dihitung
        // saat halaman baru dibuka, dan dua FAB bertag bawaan yang sama
        // (mis. "Trade" dan "Akun baru") memicu galat "multiple heroes".
        navigatorContainerBuilder: (context, shell, children) =>
            _Branches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: _page((_) => const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                pageBuilder: _page((_) => const CalendarScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trades',
                pageBuilder: _page((_) => const TradesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/funds',
                pageBuilder: _page((_) => const TransactionsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: _page((_) => const MoreScreen()),
                routes: [
                  GoRoute(
                    path: 'rules',
                    pageBuilder: _page((_) => const RulesScreen()),
                  ),
                  GoRoute(
                    path: 'analysis',
                    pageBuilder: _page((_) => const AnalysisScreen()),
                  ),
                  GoRoute(
                    path: 'reports',
                    pageBuilder: _page((_) => const ReportScreen()),
                  ),
                  GoRoute(
                    path: 'accounts',
                    pageBuilder: _page((_) => const AccountsScreen()),
                  ),
                  GoRoute(
                    path: 'profile',
                    pageBuilder: _page((_) => const ProfileScreen()),
                  ),
                  GoRoute(
                    path: 'devices',
                    pageBuilder: _page((_) => const DevicesScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Di luar shell: form dan chat memenuhi layar tanpa tab bar, sama
      // seperti layar chat di web yang menyembunyikan header dan tab bar.
      GoRoute(
        path: '/trade/new',
        parentNavigatorKey: _rootKey,
        pageBuilder: _formPage((_) => const TradeFormScreen()),
      ),
      GoRoute(
        path: '/trade/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: _formPage(
          (state) => TradeFormScreen(tradeId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: _rootKey,
        pageBuilder: _slidePage(
          (state) =>
              ChatScreen(period: state.uri.queryParameters['period'] ?? '30d'),
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

/// Cabang shell. Pindah tab langsung tanpa animasi; Lainnya (cabang terakhir,
/// dibuka dari header) masuk dari kanan di atas tab asalnya dan keluar lagi
/// ke kanan, seperti membuka halaman, bukan berganti tab.
class _Branches extends StatefulWidget {
  const _Branches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_Branches> createState() => _BranchesState();
}

class _BranchesState extends State<_Branches>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 320);

  int get _more => widget.children.length - 1;

  late final _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.index == _more ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final _in = Tween(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(_curve);

  /// Tab di bawahnya ikut bergeser sedikit ke kiri.
  late final _out = Tween(
    begin: Offset.zero,
    end: const Offset(-.25, 0),
  ).animate(_curve);

  /// Tab yang tampak di bawah Lainnya selama animasi berjalan.
  late int _base = widget.index == _more ? 0 : widget.index;

  @override
  void didUpdateWidget(_Branches old) {
    super.didUpdateWidget(old);

    if (widget.index != _more) _base = widget.index;

    if (widget.index == _more && old.index != _more) _controller.forward();
    if (widget.index != _more && old.index == _more) _controller.reverse();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;

    final moving = _controller.isAnimating;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (index, child) in widget.children.indexed)
          HeroMode(
            enabled: index == widget.index,
            child: Offstage(
              offstage:
                  index != widget.index &&
                  !(moving && (index == _base || index == _more)),
              child: TickerMode(
                enabled: index == widget.index,
                child: SlideTransition(
                  position: index == _more
                      ? _in
                      : index == _base
                      ? _out
                      : const AlwaysStoppedAnimation(Offset.zero),
                  // Bayangan di tepi kiri Lainnya saat menimpa tab; saat
                  // diam, bayangannya terpotong Stack di luar layar.
                  child: index == _more
                      ? DecoratedBox(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x73000000),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: child,
                        )
                      : child,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hanya sekejap — selama token dibaca dari Keystore/Keychain. Cukup latarnya.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
