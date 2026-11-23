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
import 'package:holodex/features/profile/widgets/whatsapp_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_wa_widget_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    final user = await AuthService.login(
      username: 'trainer_ash',
      password: 'password123',
    );
    await OrderRepository.reserveListing(
      listingId: 'listing-003',
      buyerId: user.id,
    );
  });

  group('WhatsAppDialog Widget Tests', () {
    testWidgets('Renders WhatsAppDialog and handles 320dp textScale 1.3 safely',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: WhatsAppDialog(
                initialPhone: '081234567890',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Nomor WhatsApp'), findsWidgets);
      expect(
        find.textContaining('Dipakai hanya agar pembeli dan penjual'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('Shows error message when invalid number is entered',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: WhatsAppDialog(),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '08123');
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(find.textContaining('Format nomor tidak valid'), findsOneWidget);
    });
  });

  group('MyOrdersScreen WhatsApp Contact Button Tests', () {
    testWidgets('Menampilkan tombol Hubungi via WhatsApp pada order reserved',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MyOrdersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Hubungi via WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });
  });
}
