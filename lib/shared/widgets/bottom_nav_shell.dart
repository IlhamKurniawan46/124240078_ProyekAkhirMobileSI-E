import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/dex/screens/dex_screen.dart';
import '../../features/marketplace/screens/marketplace_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

/// Shell Navigasi Bawah 3 Tab HoloDex v2.
/// Menggunakan `IndexedStack` dan `NavigationBar` (BottomNavigationBar Material 3)
/// untuk 3 tab utama:
/// - Tab 0: Dex ([DexScreen])
/// - Tab 1: Pasar ([MarketplaceScreen])
/// - Tab 2: Profil ([ProfileScreen])
class BottomNavShell extends StatefulWidget {
  final int initialIndex;

  const BottomNavShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  late int _currentIndex;

  final List<Widget> _tabs = const [
    DexScreen(),
    MarketplaceScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 62,
          backgroundColor: AppColors.surfaceLow,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.gold, size: 23);
            }
            return const IconThemeData(color: AppColors.outline, size: 23);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              );
            }
            return const TextStyle(
              color: AppColors.outline,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          height: 62,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              selectedIcon: Icon(Icons.style),
              label: 'Dex',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Pasar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
