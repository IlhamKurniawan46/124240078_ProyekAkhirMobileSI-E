import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/user_model.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/profile/screens/collection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserModel demoUser;
  late UserModel emptyUser;

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_collection_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    demoUser =
        await AuthService.login(username: 'trainer_ash', password: 'password123');
    emptyUser = const UserModel(
      id: 'user-empty-test',
      username: 'empty_collector',
      balanceIdr: 0,
    );
  });

  testWidgets(
      'CollectionScreen displays seeded binder cards and portfolio summary for trainer_ash without layout exception',
      (tester) async {
    AppState.instance.currentUser.value = demoUser;

    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(360, 800)),
          child: CollectionScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Koleksi Saya'), findsOneWidget);
    expect(find.text('Estimasi Nilai Koleksi'), findsOneWidget);
    expect(find.text('2 Kartu Fisik'), findsOneWidget);
  });

  testWidgets(
      'CollectionScreen builds empty state on 320dp with fontScale 1.3 for user with no cards',
      (tester) async {
    AppState.instance.currentUser.value = emptyUser;

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
          child: CollectionScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Koleksi Saya'), findsOneWidget);
    expect(find.text('Koleksi Masih Kosong'), findsOneWidget);
  });
}
