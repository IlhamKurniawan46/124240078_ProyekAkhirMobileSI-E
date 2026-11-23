import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/core/services/order_repository.dart';
import 'package:holodex/features/marketplace/screens/my_orders_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_my_orders_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    final user = await AuthService.login(
      username: 'trainer_ash',
      password: 'password123',
    );
    await OrderRepository.reserveListing(
      listingId: 'listing-002',
      buyerId: user.id,
    );
  });

  group('MyOrdersScreen Widget Tests', () {
    testWidgets(
      'MyOrdersScreen builds reserved order on 320dp with fontScale 1.3 without layout exception',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 1100 * 2);
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
                size: Size(320, 1100),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MyOrdersScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Pesanan'), findsOneWidget);
        expect(find.text('Pembelian'), findsOneWidget);
        expect(find.text('Penjualan'), findsOneWidget);
        expect(find.text('Dipesan'), findsWidgets);
        expect(find.text('Sudah Kuterima'), findsOneWidget);
        expect(find.text('Batalkan'), findsOneWidget);
      },
    );

    testWidgets(
        'MyOrdersScreen klik Batalkan membuka dialog konfirmasi dan dapat ditutup kembali',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyOrdersScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cancelButton = find.widgetWithText(OutlinedButton, 'Batalkan');
      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Batalkan Pesanan?'), findsOneWidget);
      expect(find.text('Ya, Batalkan'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      await tester.tap(find.text('Kembali'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Batalkan Pesanan?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
