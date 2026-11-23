import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/repositories/card_repository.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_search_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
  });

  group('SearchScreen & CardRepository Filter Tests', () {
    test('CardModel serialization round-trip preserves all fields', () {
      const card = CardModel(
        id: 'swsh3-1',
        localId: '1',
        name: 'Butterfree V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Rare Holo V',
        cardType: 'Grass',
        priceIdr: 25000,
        priceRefUsd: 1.5,
        hasPrice: true,
      );

      final map = card.toMap();
      expect(map['id'], equals('swsh3-1'));
      expect(map['name'], equals('Butterfree V'));
      expect(map['set_id'], equals('swsh3'));
      expect(map['rarity'], equals('Rare Holo V'));
      expect(map['price_idr'], equals(25000));

      final restored = CardModel.fromMap(map);
      expect(restored.id, equals(card.id));
      expect(restored.name, equals(card.name));
      expect(restored.setId, equals(card.setId));
      expect(restored.rarity, equals(card.rarity));
      expect(restored.priceIdr, equals(card.priceIdr));
      expect(restored.hasPrice, isTrue);
    });

    test('CardRepository searchCards filters by query and setId', () {
      final umbreon = CardRepository.searchCards(query: 'Umbreon');
      expect(umbreon, isNotEmpty);
      expect(umbreon.first.name, contains('Umbreon'));

      final swsh7Cards = CardRepository.searchCards(setId: 'swsh7');
      expect(swsh7Cards, isNotEmpty);
      expect(swsh7Cards.every((c) => c.setId == 'swsh7'), isTrue);
    });

    testWidgets(
        'SearchScreen renders search bar and results safely on 320dp & fontScale 1.3',
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
            child: SearchScreen(initialQuery: 'Charizard'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Charizard'), findsWidgets);
    });
  });
}
