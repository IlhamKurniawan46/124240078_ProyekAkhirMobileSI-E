import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/models/transaction_model.dart';
import 'package:holodex/core/models/user_model.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/marketplace/screens/create_listing_screen.dart';
import 'package:holodex/features/marketplace/screens/listing_detail_screen.dart';
import 'package:holodex/features/marketplace/screens/marketplace_screen.dart';
import 'package:holodex/features/marketplace/screens/transaction_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserModel demoUser;

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_marketplace_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
    await CurrencyService.initRates();
    demoUser =
        await AuthService.login(username: 'trainer_ash', password: 'password123');
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

  const sampleBuyerListing = ListingModel(
    id: 'list-101',
    cardId: 'swsh3-19',
    sellerId: 'user-seller-001',
    sellerUsername: 'seller_jakarta',
    priceIdr: 220000,
    condition: 'mint',
    description: 'Kondisi prima no scratch.',
    card: sampleCard,
    status: 'active',
  );

  const sampleOwnerListing = ListingModel(
    id: 'listing-ash-015',
    cardId: 'swsh3-19',
    sellerId: InitialDataSeeder.demoUserId,
    sellerUsername: 'trainer_ash',
    priceIdr: 185000,
    condition: 'near_mint',
    description: 'Kartu milik trainer_ash siap COD.',
    card: sampleCard,
    status: 'active',
  );

  group('Unit Tests: ListingModel & TransactionModel', () {
    test('ListingModel fromJson and toJson serialization', () {
      final json = sampleBuyerListing.toJson();
      final parsed = ListingModel.fromJson(json);

      expect(parsed.id, 'list-101');
      expect(parsed.priceIdr, 220000);
      expect(parsed.condition, 'mint');
      expect(parsed.conditionLabel, 'Mint (Sempurna)');
      expect(parsed.sellerUsername, 'seller_jakarta');
      expect(parsed.card?.name, 'Charizard V');
    });

    test('TransactionModel fromJson and toJson serialization', () {
      final transaction = TransactionModel(
        id: 'tx-201',
        listingId: 'list-101',
        buyerId: InitialDataSeeder.demoUserId,
        sellerId: 'user-seller-001',
        cardId: 'swsh3-19',
        priceIdr: 220000,
        createdAt: DateTime.parse('2026-10-22T10:00:00Z'),
        card: sampleCard,
        buyerUsername: 'trainer_ash',
        sellerUsername: 'seller_jakarta',
        isBuyer: true,
      );

      final json = transaction.toJson();
      final parsed = TransactionModel.fromJson(json);

      expect(parsed.id, 'tx-201');
      expect(parsed.priceIdr, 220000);
      expect(parsed.isBuyer, true);
      expect(parsed.buyerUsername, 'trainer_ash');
      expect(parsed.sellerUsername, 'seller_jakarta');
    });
  });

  group('Widget Tests: Marketplace Screens (CRUD + Edit Listing + Anti-Overflow)', () {
    testWidgets(
        'MarketplaceScreen builds grid on 320dp with fontScale 1.3 without error',
        (tester) async {
      AppState.instance.currentUser.value = demoUser;

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
            child: MarketplaceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Marketplace'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets(
        'ListingDetailScreen renders "Pesan" button for buyer on 320dp without error',
        (tester) async {
      AppState.instance.currentUser.value = demoUser;

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
            child: ListingDetailScreen(
              listingId: 'list-101',
              initialListing: sampleBuyerListing,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Charizard V'), findsWidgets);
      expect(find.text('Pesan'), findsOneWidget);
      expect(find.text('@seller_jakarta'), findsOneWidget);
    });

    testWidgets(
        'ListingDetailScreen renders "Edit Listing" and "Batalkan" for listing owner (Update & Delete CRUD)',
        (tester) async {
      AppState.instance.currentUser.value = demoUser;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ListingDetailScreen(
            listingId: 'listing-ash-015',
            initialListing: sampleOwnerListing,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Listing'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);
    });

    testWidgets(
        'CreateListingScreen in Edit Mode pre-populates price and description from existingListing',
        (tester) async {
      AppState.instance.currentUser.value = demoUser;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CreateListingScreen(
            existingListing: sampleOwnerListing,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Listing Kartu'), findsOneWidget);
      expect(find.text('185000'), findsOneWidget);
    });

    testWidgets(
        'TransactionHistoryScreen renders tabs without error',
        (tester) async {
      AppState.instance.currentUser.value = demoUser;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TransactionHistoryScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Pembelian Saya'), findsOneWidget);
      expect(find.text('Penjualan Saya'), findsOneWidget);
    });
  });
}
