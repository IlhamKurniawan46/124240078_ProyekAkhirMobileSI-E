import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/marketplace/screens/map_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_map_screen_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
  });

  const sampleCard = CardModel(
    id: 'swsh3-19',
    localId: '19',
    name: 'Charizard V',
    setId: 'swsh3',
    setName: 'Darkness Ablaze',
    rarity: 'Ultra Rare',
    priceIdr: 250000,
    priceUsd: 15.5,
    hasPrice: true,
  );

  const codListing = ListingModel(
    id: 'order-listing-99',
    sellerId: 'user-seller-1',
    sellerUsername: 'penjual_bandung',
    cardId: 'swsh3-19',
    card: sampleCard,
    priceIdr: 250000,
    condition: 'near_mint',
    lat: -6.9175,
    lng: 107.6191,
    status: 'reserved',
  );

  group('MapScreen Widget Tests (LBS & Anti-Overflow)', () {
    testWidgets(
        'MapScreen renders AppBar, radius chips, and FAB on 320dp without error',
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
            child: MapScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Peta Penjual Terdekat'), findsOneWidget);
      expect(find.text('Semua Jarak'), findsOneWidget);
      expect(find.text('5 km'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets(
        'MapScreen renders COD initialCenter and focusedListing pin with bottom card',
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
            child: MapScreen(
              initialCenter: LatLng(-6.9175, 107.6191),
              initialZoom: 15.5,
              focusedListing: codListing,
              title: 'Titik COD Pesanan',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Titik COD Pesanan'), findsOneWidget);
      expect(find.byIcon(Icons.handshake), findsWidgets);
      expect(find.text('Charizard V'), findsOneWidget);
      expect(find.text('Lihat Detail Kartu'), findsOneWidget);
    });
  });
}
