import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/auth_service.dart';
import 'package:holodex/core/services/collection_repository.dart';
import 'package:holodex/core/services/marketplace_repository.dart';
import 'package:holodex/core/services/order_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('holodex_market_test_');
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

  group('Sesi 6 — Marketplace CRUD (termasuk Edit Listing), Rekber COD & WhatsApp Privacy', () {
    test('CRUD Listing Lengkap: Create, Read, Update (Edit Listing + Otorisasi), dan Delete (Cancel)', () async {
      const ashId = InitialDataSeeder.demoUserId;
      const otherSellerId = 'seller-jkt-01';

      // 1. CREATE Listing Baru
      final newListingId = await MarketplaceRepository.createListing(
        cardId: 'swsh3-19',
        sellerId: ashId,
        priceIdr: 150000.0,
        condition: 'near_mint',
        description: 'Charizard V siap COD Jakarta.',
        lat: -6.1754,
        lng: 106.8272,
      );

      // 2. READ Listing Detail
      final created = await MarketplaceRepository.getListingDetail(newListingId);
      expect(created, isNotNull);
      expect(created!.priceIdr, 150000.0);
      expect(created.condition, 'near_mint');

      // 3. UPDATE (Edit Listing) oleh Pemilik Sah -> Berhasil
      final updated = await MarketplaceRepository.updateListing(
        listingId: newListingId,
        currentUserId: ashId,
        priceIdr: 185000.0,
        condition: 'mint',
        description: 'Harga & kondisi diperbarui ke Mint!',
        lat: -6.2000,
        lng: 106.8500,
      );
      expect(updated.priceIdr, 185000.0);
      expect(updated.condition, 'mint');
      expect(updated.description, 'Harga & kondisi diperbarui ke Mint!');

      // 4. OTORISASI UPDATE: Penjual lain mencoba mengedit listing milik Ash -> Ditolak!
      expect(
        () => MarketplaceRepository.updateListing(
          listingId: newListingId,
          currentUserId: otherSellerId,
          priceIdr: 50000.0,
          condition: 'poor',
        ),
        throwsA(isA<MarketplaceFailure>()),
      );

      // 5. DELETE (Cancel Listing) oleh Pemilik Sah -> Berhasil
      final cancelled = await MarketplaceRepository.cancelListing(
        listingId: newListingId,
        sellerId: ashId,
      );
      expect(cancelled, isTrue);

      final afterCancel =
          await MarketplaceRepository.getListingDetail(newListingId);
      expect(afterCancel?.isCancelled, isTrue);
    });

    test('Alur Rekber COD: Reserve menahan saldo, WhatsApp Contact terbuka, Confirm memindahkan saldo & kartu ke Binder', () async {
      const buyerId = InitialDataSeeder.demoUserId; // Saldo awal Rp 2.500.000
      const listingId = 'listing-001'; // Charizard VMAX milik misty_cards, Rp 625.000

      // 1. Reserve Listing
      final res = await OrderRepository.reserveListing(
        listingId: listingId,
        buyerId: buyerId,
      );
      expect(res['ok'], isTrue);
      final orderId = res['order_id'] as String;

      final buyerAfterReserve = await AuthService.getUserById(buyerId);
      expect(buyerAfterReserve?.balanceIdr, 2500000.0 - 625000.0);

      // 2. Get WhatsApp Contact saat status 'reserved' -> Diizinkan
      final contact = await OrderRepository.getOrderContact(
        orderId: orderId,
        userId: buyerId,
      );
      expect(contact.ok, isTrue);
      expect(contact.whatsappNumber, isNotNull);

      // 3. Confirm Receipt (Serah terima COD selesai)
      final sellerBefore = await AuthService.getUserById('seller-jkt-01');
      final confirmRes = await OrderRepository.confirmReceipt(
        orderId: orderId,
        buyerId: buyerId,
      );
      expect(confirmRes['ok'], isTrue);

      // Saldo penjual bertambah Rp 625.000
      final sellerAfter = await AuthService.getUserById('seller-jkt-01');
      expect(sellerAfter!.balanceIdr, sellerBefore!.balanceIdr + 625000.0);

      // Kartu swsh3-20 otomatis masuk ke Binder Koleksi pembeli
      expect(
        await CollectionRepository.isCardInCollection(buyerId, 'swsh3-20'),
        isTrue,
      );

      // 4. Get WhatsApp Contact setelah pesanan 'completed' -> Ditolak demi privasi!
      final contactAfter = await OrderRepository.getOrderContact(
        orderId: orderId,
        userId: buyerId,
      );
      expect(contactAfter.ok, isFalse);
      expect(contactAfter.errorCode, 'not_allowed');
    });

    test('Cancel Order mengembalikan saldo 100% ke pembeli dan mengaktifkan kembali listing', () async {
      const buyerId = InitialDataSeeder.demoUserId;
      const listingId = 'listing-002'; // Miraidon ex Rp 430.000

      final res = await OrderRepository.reserveListing(
        listingId: listingId,
        buyerId: buyerId,
      );
      final orderId = res['order_id'] as String;

      final cancelRes = await OrderRepository.cancelOrder(
        orderId: orderId,
        userId: buyerId,
        reason: 'Jadwal COD berubah',
      );
      expect(cancelRes['ok'], isTrue);

      // Saldo pembeli kembali utuh Rp 2.500.000
      final buyerAfterCancel = await AuthService.getUserById(buyerId);
      expect(buyerAfterCancel?.balanceIdr, 2500000.0);

      // Listing aktif kembali
      final listingAfter = await MarketplaceRepository.getListingDetail(listingId);
      expect(listingAfter?.isActive, isTrue);
    });
  });
}
