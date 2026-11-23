import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/base_entity.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/models/user_model.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('holodex_hive_test_');
    await HiveDatabase.init(customPath: tempDir.path);
  });

  tearDownAll(() async {
    await HiveDatabase.closeAll();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Sesi 2 — OOP BaseEntity, HiveDatabase 10 Box & InitialDataSeeder', () {
    test('10 Hive Box terbuka dan InitialDataSeeder mengisi data awal dengan lengkap', () async {
      await HiveDatabase.clearAll();
      await InitialDataSeeder.seedIfNeeded();

      expect(HiveDatabase.isInitialized, isTrue);
      expect(HiveDatabase.settingsBox.get('is_seeded'), isTrue);

      // 1 akun demo + 10 penjual = 11 user
      expect(HiveDatabase.usersBox.length, 11);
      // 24 kartu katalog awal
      expect(HiveDatabase.cardsBox.length, 24);
      // 15 listing aktif
      expect(HiveDatabase.listingsBox.length, 15);
      // 2 koleksi binder awal untuk trainer_ash
      expect(HiveDatabase.collectionsBox.length, 2);
      // 2 watchlist awal untuk trainer_ash
      expect(HiveDatabase.watchlistBox.length, 2);
      // 1 riwayat transaksi awal
      expect(HiveDatabase.transactionsBox.length, 1);
    });

    test('Polimorfisme OOP BaseEntity bekerja pada UserModel, CardModel, dan ListingModel', () {
      final rawUser = HiveDatabase.readMap(
        HiveDatabase.usersBox.get(InitialDataSeeder.demoUserId),
      );
      final rawCard = HiveDatabase.readMap(
        HiveDatabase.cardsBox.get('swsh7-215'),
      );
      final rawListing = HiveDatabase.readMap(
        HiveDatabase.listingsBox.get('listing-ash-015'),
      );

      final List<BaseEntity> entities = [
        UserModel.fromMap(rawUser),
        CardModel.fromMap(rawCard),
        ListingModel.fromMap(rawListing),
      ];

      expect(entities[0].id, InitialDataSeeder.demoUserId);
      expect(entities[1].id, 'swsh7-215');
      expect(entities[2].id, 'listing-ash-015');
      for (final entity in entities) {
        expect(entity.toMap()['id'], entity.id);
      }
    });

    test('AppState menyimpan perubahan mata uang ke holodex_settings box', () async {
      await AppState.instance.setCurrency(AppCurrency.jpy);
      expect(AppState.instance.selectedCurrency.value, AppCurrency.jpy);
      expect(HiveDatabase.settingsBox.get('selected_currency'), 'JPY');

      await AppState.instance.setCurrency(AppCurrency.idr);
      expect(AppState.instance.selectedCurrency.value, AppCurrency.idr);
    });
  });
}
