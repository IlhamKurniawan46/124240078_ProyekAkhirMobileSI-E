import 'package:flutter/material.dart';

import '../features/auth/screens/splash_screen.dart';
import 'navigation_keys.dart';
import 'theme.dart';

class HoloDexApp extends StatelessWidget {
  const HoloDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoloDex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: rootNavigatorKey,
      home: const SplashScreen(),
    );
  }
}
