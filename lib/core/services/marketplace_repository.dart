import 'package:uuid/uuid.dart';

import '../database/hive_database.dart';
import '../models/card_model.dart';
import '../models/listing_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Custom Exception untuk kegagalan operasi Marketplace.
class MarketplaceFailure implements Exception {
  final String message;
  const MarketplaceFailure(this.message);

  @override
  String toString() => message;
}

class MarketplaceRepository {
  MarketplaceRepository._();

  static const _uuid = Uuid();

  /// [READ] Mengambil daftar semua listing aktif (dan dipesan) di Marketplace dari `holodex_listings` Hive Box.
  static Future<List<ListingModel>> fetchActiveListings({
    String? cardId,
    String? sellerId,
    bool includeReserved = true,
  }) async {
    final results = <ListingModel>[];

    for (final raw in HiveDatabase.listingsBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      final status = map['status'] as String? ?? 'active';

      if (status != 'active' && !(includeReserved && status == 'reserved')) {
        continue;
      }
      if (cardId != null && map['card_id'] != cardId) continue;
      if (sellerId != null && map['seller_id'] != sellerId) continue;

      results.add(_hydrateListing(map));
    }

    results.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return results;
  }

  /// [READ] Mengambil detail satu listing berdasarkan ID dari `holodex_listings` Hive Box.
  static Future<ListingModel?> getListingDetail(String listingId) async {
    final raw = HiveDatabase.listingsBox.get(listingId);
    if (raw == null || raw is! Map) return null;
    return _hydrateListing(HiveDatabase.readMap(raw));
  }

  /// [CREATE] Membuat listing kartu baru di `holodex_listings` Hive Box.
  static Future<String> createListing({
    required String cardId,
    required String sellerId,
    required double priceIdr,
    required String condition,
    String? description,
    double? lat,
    double? lng,
  }) async {
    if (priceIdr < 1000) {
      throw const MarketplaceFailure('Harga minimal listing adalah Rp 1.000.');
    }

    final seller = await AuthService.getUserById(sellerId);
    if (seller == null) {
      throw const MarketplaceFailure('Akun penjual tidak ditemukan.');
    }
    if (seller.whatsappNumber == null || seller.whatsappNumber!.trim().isEmpty) {
      throw const MarketplaceFailure(
        'Nomor WhatsApp wajib diisi terlebih dahulu untuk koordinasi COD.',
      );
    }

    CardModel? card;
    final rawCard = HiveDatabase.cardsBox.get(cardId);
    if (rawCard != null && rawCard is Map) {
      card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
    }

    final now = DateTime.now().toUtc();
    final listingId = 'listing-${_uuid.v4().substring(0, 8)}';

    final newListing = ListingModel(
      id: listingId,
      cardId: cardId,
      sellerId: sellerId,
      sellerUsername: seller.username,
      sellerPhotoUrl: seller.photoUrl,
      priceIdr: priceIdr,
      condition: condition,
      description: description?.trim(),
      lat: lat,
      lng: lng,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      card: card,
    );

    await HiveDatabase.listingsBox.put(listingId, newListing.toMap());
    return listingId;
  }

  /// [UPDATE] Mengubah data listing aktif milik penjual (`priceIdr`, `condition`, `description`, `lat`, `lng`).
  static Future<ListingModel> updateListing({
    required String listingId,
    required String currentUserId,
    required double priceIdr,
    required String condition,
    String? description,
    double? lat,
    double? lng,
  }) async {
    final raw = HiveDatabase.listingsBox.get(listingId);
    if (raw == null || raw is! Map) {
      throw const MarketplaceFailure('Listing tidak ditemukan.');
    }

    final existing = _hydrateListing(HiveDatabase.readMap(raw));

    // Otorisasi kepemilikan
    if (existing.sellerId != currentUserId) {
      throw const MarketplaceFailure(
        'Otorisasi ditolak: Anda hanya dapat mengedit listing milik sendiri.',
      );
    }

    // Validasi status
    if (existing.status != 'active') {
      throw const MarketplaceFailure(
        'Hanya listing berstatus Aktif yang dapat diubah.',
      );
    }

    if (priceIdr < 1000) {
      throw const MarketplaceFailure('Harga minimal listing adalah Rp 1.000.');
    }

    final updated = existing.copyWith(
      priceIdr: priceIdr,
      condition: condition,
      description: description?.trim(),
      lat: lat,
      lng: lng,
      updatedAt: DateTime.now().toUtc(),
    );

    await HiveDatabase.listingsBox.put(listingId, updated.toMap());
    return updated;
  }

  /// [DELETE] Membatalkan listing aktif milik sendiri di `holodex_listings` Hive Box.
  static Future<bool> cancelListing({
    required String listingId,
    required String sellerId,
  }) async {
    final raw = HiveDatabase.listingsBox.get(listingId);
    if (raw == null || raw is! Map) {
      throw const MarketplaceFailure('Listing tidak ditemukan.');
    }

    final map = HiveDatabase.readMap(raw);
    if (map['seller_id'] != sellerId) {
      throw const MarketplaceFailure(
        'Otorisasi ditolak: Anda tidak dapat membatalkan listing milik penjual lain.',
      );
    }
    if (map['status'] != 'active') {
      throw const MarketplaceFailure(
        'Listing yang sedang dipesan atau sudah terjual tidak dapat dibatalkan dari sini.',
      );
    }

    map['status'] = 'cancelled';
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await HiveDatabase.listingsBox.put(listingId, map);
    return true;
  }

  /// [READ] Mengambil riwayat transaksi selesai pengguna (pembelian & penjualan) dari `holodex_transactions` Hive Box.
  static Future<List<TransactionModel>> getUserTransactions(
    String userId,
  ) async {
    final list = <TransactionModel>[];

    for (final raw in HiveDatabase.transactionsBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      final buyerId = map['buyer_id'] as String?;
      final sellerId = map['seller_id'] as String?;

      if (buyerId != userId && sellerId != userId) continue;

      final cardId = map['card_id'] as String? ?? '';
      CardModel? card;
      final rawCard = HiveDatabase.cardsBox.get(cardId);
      if (rawCard != null && rawCard is Map) {
        card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
      }

      final tx = TransactionModel.fromMap(map).copyWith(
        card: card,
        isBuyer: buyerId == userId,
      );
      list.add(tx);
    }

    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return list;
  }

  /// Mengambil profil user terbaru dari `holodex_users` Hive Box.
  static Future<UserModel?> getUserProfile(String userId) {
    return AuthService.getUserById(userId);
  }

  /// Top up saldo virtual di `holodex_users` Hive Box.
  static Future<double> topUpBalance({
    required String userId,
    required double amount,
  }) async {
    try {
      return await AuthService.topUpBalance(userId: userId, amountIdr: amount);
    } on AuthFailure catch (e) {
      throw MarketplaceFailure(e.message);
    }
  }

  static ListingModel _hydrateListing(Map<String, dynamic> map) {
    final cardId = map['card_id'] as String? ?? '';
    final sellerId = map['seller_id'] as String? ?? '';

    CardModel? card;
    final rawCard = HiveDatabase.cardsBox.get(cardId);
    if (rawCard != null && rawCard is Map) {
      card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
    }

    String? sellerUsername = map['seller_username'] as String?;
    String? sellerPhotoUrl = map['seller_photo_url'] as String?;
    final rawSeller = HiveDatabase.usersBox.get(sellerId);
    if (rawSeller != null && rawSeller is Map) {
      final sellerMap = HiveDatabase.readMap(rawSeller);
      sellerUsername = (sellerMap['username'] as String?) ?? sellerUsername;
      sellerPhotoUrl = (sellerMap['photo_url'] as String?) ?? sellerPhotoUrl;
    }

    return ListingModel.fromMap(map).copyWith(
      card: card,
      sellerUsername: sellerUsername,
      sellerPhotoUrl: sellerPhotoUrl,
    );
  }
}
