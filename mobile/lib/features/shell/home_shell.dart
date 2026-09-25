import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tab bar bawah, sama urutannya dengan tab bar mobile di web: Dashboard,
/// Kalender, Trade di tengah, Dana, lalu Lainnya (aturan, analisa, laporan…).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      // Mengetuk tab yang sedang aktif kembali ke layar teratasnya.
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Kalender',
        ),
        NavigationDestination(
          icon: Icon(Icons.format_list_numbered),
          selectedIcon: Icon(Icons.format_list_numbered_rtl),
          label: 'Trade',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Dana',
        ),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Lainnya'),
      ],
    ),
  );
}
