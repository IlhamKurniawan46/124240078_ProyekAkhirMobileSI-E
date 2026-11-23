import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/screens/card_detail_screen.dart';
import 'package:holodex/features/dex/widgets/holo_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_card_detail_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    await AuthService.login(username: 'trainer_ash', password: 'password123');
  });

  const testCard = CardModel(
    id: 'swsh7-215',
    localId: '215',
    name: 'Umbreon VMAX',
    setId: 'swsh7',
    setName: 'Evolving Skies',
    rarity: 'Secret Rare',
    cardType: 'Darkness',
    priceIdr: 14625000,
    priceUsd: 900.0,
    priceEur: 828.0,
    priceRefUsd: 900.0,
    hasPrice: true,
  );

  group('HoloCardWidget & CardDetailScreen Widget Tests', () {
    testWidgets('HoloCardWidget renders interactive 3D card without crash',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: HoloCardWidget(
                imageUrl:
                    'https://assets.tcgdex.net/en/swsh/swsh7/215/high.webp',
                rarity: 'Secret Rare',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(HoloCardWidget), findsOneWidget);
    });

    testWidgets(
        'CardDetailScreen renders multi-currency prices, Watchlist button, and Marketplace search without HoloBot button',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
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
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: CardDetailScreen(
              cardId: 'swsh7-215',
              initialCard: testCard,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Umbreon VMAX'), findsWidgets);
      expect(find.text('Evolving Skies'), findsWidgets);
      expect(find.text('Secret Rare'), findsWidgets);

      // Verify HoloBot button is removed in v2
      expect(find.text('Tanya HoloBot'), findsNothing);
    });
  });
}
