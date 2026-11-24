import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/screens/dex_screen.dart';
import 'package:holodex/shared/widgets/bottom_nav_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_dex_screen_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    await AuthService.login(username: 'trainer_ash', password: 'password123');
  });

  testWidgets(
      'DexScreen renders currency selector chips (IDR, USD, EUR, JPY) without removed utility tiles safely on 320dp & fontScale 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: DexScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Konverter Kurs'), findsNothing);
    expect(find.text('Event & Pengingat'), findsNothing);
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('IDR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('JPY'), findsOneWidget);

    await tester.tap(find.text('USD'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(AppState.instance.selectedCurrency.value, AppCurrency.usd);

    await tester.tap(find.text('IDR'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(AppState.instance.selectedCurrency.value, AppCurrency.idr);
  });

  testWidgets(
      'BottomNavShell renders 4 tabs (Dex, Pasar, Event, Profil) and switches to Event tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const BottomNavShell(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Dex'), findsOneWidget);
    expect(find.text('Pasar'), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Event dan Pengingat'), findsOneWidget);
  });
}
