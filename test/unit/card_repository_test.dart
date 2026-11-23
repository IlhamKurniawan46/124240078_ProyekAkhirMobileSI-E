import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/repositories/card_repository.dart';
import 'package:holodex/core/services/collection_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('holodex_card_repo_test_');
    await HiveDatabase.init(customPath: tempDir.path);
  });

  setUp(() async {
    await HiveDatabase.clearAll();
    await InitialDataSeeder.seedIfNeeded();
  });

  tearDownAll(() async {
    await HiveDatabase.closeAll();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Sesi 4 — CardRepository (Hive Query, Search, Filter & TCGdex API Parser)', () {
    test('getAllCards mengembalikan kartu terurut dari Termahal ke Termurah atau Termurah ke Termahal', () {
      final expensiveFirst = CardRepository.getAllCards(
        sortOrder: SortOrder.expensiveFirst,
      );
      expect(expensiveFirst.length, 24);
      expect(
        expensiveFirst.first.priceRefUsd! >= expensiveFirst.last.priceRefUsd!,
        isTrue,
      );

      final cheapestFirst = CardRepository.getAllCards(
        sortOrder: SortOrder.cheapestFirst,
      );
      expect(
        cheapestFirst.first.priceRefUsd! <= cheapestFirst.last.priceRefUsd!,
        isTrue,
      );
    });

    test('searchCards mendukung pencarian nama, filter setId, filter rarity, dan rentang harga IDR', () {
      final charizards = CardRepository.searchCards(query: 'Charizard');
      expect(charizards.length, 2);

      final swsh7Secret = CardRepository.searchCards(
        setId: 'swsh7',
        rarity: 'Secret Rare',
      );
      expect(swsh7Secret.length, 5);

      final affordable = CardRepository.searchCards(
        maxPriceIdr: 150000.0,
      );
      expect(affordable.isNotEmpty, isTrue);
    });

    test('parseTcgdexCardJson mengekstrak harga marketPrice tertinggi dari TCGplayer & Cardmarket', () {
      final sampleJson = {
        'id': 'sv01-081',
        'localId': '081',
        'name': 'Miraidon ex',
        'image': 'https://assets.tcgdex.net/en/sv/sv01/081',
        'rarity': 'Double Rare',
        'types': ['Lightning'],
        'set': {'id': 'sv01', 'name': 'Scarlet & Violet'},
        'pricing': {
          'tcgplayer': {
            'normal': {'marketPrice': 3.20},
            'holofoil': {'marketPrice': 5.75},
          },
          'cardmarket': {
            'trend': 4.80,
          },
        },
      };

      final parsed = CardRepository.parseTcgdexCardJson(sampleJson);
      expect(parsed, isNotNull);
      expect(parsed!.id, 'sv01-081');
      expect(parsed.priceUsd, 5.75);
      expect(parsed.priceEur, 4.80);
      expect(parsed.priceRefUsd, 5.75);
      expect(parsed.hasPrice, isTrue);
      expect(parsed.priceSource, 'tcgplayer');
    });

    test('CollectionRepository Watchlist CRUD (Create, Read, Update, Delete) di Hive bekerja penuh', () async {
      const userId = InitialDataSeeder.demoUserId;
      const cardId = 'swsh3-20';

      // Create
      await CollectionRepository.addToWatchlist(
        userId,
        cardId,
        alertPriceIdr: 500000.0,
      );
      expect(await CollectionRepository.isInWatchlist(userId, cardId), isTrue);

      // Update Target Harga
      await CollectionRepository.updateAlertPrice(userId, cardId, 450000.0);
      final updated = await CollectionRepository.getWatchlistItem(userId, cardId);
      expect(updated?.alertPriceIdr, 450000.0);

      // Delete
      await CollectionRepository.removeFromWatchlist(userId, cardId);
      expect(await CollectionRepository.isInWatchlist(userId, cardId), isFalse);
    });
  });
}
