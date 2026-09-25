import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/session.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/analysis/chat_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/more/more_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/reports/report_screen.dart';
import 'features/rules/rules_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/trades/trade_form_screen.dart';
import 'features/trades/trades_screen.dart';
import 'features/transactions/transactions_screen.dart';

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
GoRouterPageBuilder _page(Widget Function(GoRouterState state) child) =>
    (context, state) => MaterialPage<void>(
      key: state.pageKey,
      name: state.name,
      child: child(state),
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
      final atAuth = location == '/login' || location == '/register';

      if (!session.hasValue) return location == '/splash' ? null : '/splash';

      if (session.value == null) return atAuth ? null : '/login';

      return atAuth || location == '/splash' ? '/' : null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
    routes: [
      GoRoute(path: '/splash', pageBuilder: _page((_) => const _Splash())),
      GoRoute(path: '/login', pageBuilder: _page((_) => const LoginScreen())),
      GoRoute(
        path: '/register',
        pageBuilder: _page((_) => const RegisterScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
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
        pageBuilder: _page((_) => const TradeFormScreen()),
      ),
      GoRoute(
        path: '/trade/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: _page(
          (state) => TradeFormScreen(tradeId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: _rootKey,
        pageBuilder: _page(
          (state) =>
              ChatScreen(period: state.uri.queryParameters['period'] ?? '30d'),
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
