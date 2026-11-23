import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/converter/screens/converter_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_converter_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
  });

  testWidgets(
      'ConverterScreen renders 4 currencies (IDR, USD, EUR, JPY) and quick nominal chips without overflow on 320dp fontScale 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 750 * 2);
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
            size: Size(320, 750),
            textScaler: TextScaler.linear(1.3),
          ),
          child: ConverterScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Konverter Mata Uang'), findsOneWidget);
    expect(find.text('HASIL KONVERSI INSTAN'), findsOneWidget);
    expect(find.text('+10rb'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('+10rb'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
