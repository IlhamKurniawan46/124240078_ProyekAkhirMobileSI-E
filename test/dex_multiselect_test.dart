import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/screens/dex_screen.dart';
import 'package:holodex/features/dex/widgets/card_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_dex_multiselect_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    await AuthService.login(username: 'trainer_ash', password: 'password123');
  });

  testWidgets(
      'DexScreen multi-select triggers contextual AppBar and handles 320dp fontScale 1.3 safely',
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
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.byType(CardTile), findsWidgets);

    await tester.longPress(find.byType(CardTile).first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('1 dipilih'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('1 dipilih'), findsNothing);
    expect(find.text('Katalog'), findsOneWidget);
  });
}
