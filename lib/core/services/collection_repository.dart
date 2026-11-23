import '../database/hive_database.dart';
import '../models/card_model.dart';
import '../models/collection_item_model.dart';
import '../models/watchlist_item_model.dart';

class CollectionRepository {
  CollectionRepository._();

  /// Mengambil daftar kartu di Binder Koleksi milik pengguna (`userId`),
  /// di-join dengan data kartu dari `holodex_cards` box dan diurutkan terbaru.
  static Future<List<CollectionItemModel>> getCollectionCards(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final items = <CollectionItemModel>[];

    for (final raw in HiveDatabase.collectionsBox.values) {
      final map = HiveDatabase.readMap(raw);
      if (map['user_id'] != userId) continue;

      final cardId = map['card_id'] as String? ?? '';
      CardModel? card;
      final rawCard = HiveDatabase.cardsBox.get(cardId);
      if (rawCard != null && rawCard is Map) {
        card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
      }

      items.add(CollectionItemModel.fromMap(map, card: card));
    }

    items.sort((a, b) {
      final aTime = a.acquiredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.acquiredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return items;
  }

  /// Cek apakah kartu tertentu sudah dimiliki pengguna di Binder Koleksi Saya.
  static Future<bool> isCardInCollection(String userId, String cardId) async {
    final key = '${userId}_$cardId';
    if (HiveDatabase.collectionsBox.containsKey(key)) return true;

    for (final raw in HiveDatabase.collectionsBox.values) {
      final map = HiveDatabase.readMap(raw);
      if (map['user_id'] == userId && map['card_id'] == cardId) {
        return true;
      }
    }
    return false;
  }

  /// Menambahkan kartu ke Binder Koleksi pembeli (dipanggil saat konfirmasi serah terima COD).
  static Future<void> addCardToCollection({
    required String userId,
    required String cardId,
    String acquiredVia = 'purchase',
  }) async {
    final key = '${userId}_$cardId';
    final item = CollectionItemModel(
      cardId: cardId,
      userId: userId,
      acquiredVia: acquiredVia,
      acquiredAt: DateTime.now().toUtc(),
    );
    await HiveDatabase.collectionsBox.put(key, item.toMap());
  }

  /// Menghapus kartu dari Binder Koleksi penjual saat kartu tersebut terjual ke pembeli lain.
  static Future<void> removeCardFromCollection({
    required String userId,
    required String cardId,
  }) async {
    final key = '${userId}_$cardId';
    await HiveDatabase.collectionsBox.delete(key);
  }

  /// [READ] Cek apakah kartu ada di Watchlist pengguna.
  static Future<bool> isInWatchlist(String userId, String cardId) async {
    final key = '${userId}_$cardId';
    if (HiveDatabase.watchlistBox.containsKey(key)) return true;

    for (final raw in HiveDatabase.watchlistBox.values) {
      final map = HiveDatabase.readMap(raw);
      if (map['user_id'] == userId && map['card_id'] == cardId) {
        return true;
      }
    }
    return false;
  }

  /// [READ] Ambil satu item Watchlist berdasarkan `userId` dan `cardId`.
  static Future<WatchlistItemModel?> getWatchlistItem(
    String userId,
    String cardId,
  ) async {
    final key = '${userId}_$cardId';
    final raw = HiveDatabase.watchlistBox.get(key);
    if (raw == null || raw is! Map) return null;

    final map = HiveDatabase.readMap(raw);
    CardModel? card;
    final rawCard = HiveDatabase.cardsBox.get(cardId);
    if (rawCard != null && rawCard is Map) {
      card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
    }
    return WatchlistItemModel.fromMap(map, card: card);
  }

  /// [READ] Ambil seluruh daftar Watchlist untuk `userId` lengkap dengan detail `CardModel`.
  static Future<List<WatchlistItemModel>> getWatchlist(String userId) async {
    final items = <WatchlistItemModel>[];

    for (final raw in HiveDatabase.watchlistBox.values) {
      final map = HiveDatabase.readMap(raw);
      if (map['user_id'] != userId) continue;

      final cardId = map['card_id'] as String? ?? '';
      CardModel? card;
      final rawCard = HiveDatabase.cardsBox.get(cardId);
      if (rawCard != null && rawCard is Map) {
        card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
      }

      items.add(WatchlistItemModel.fromMap(map, card: card));
    }

    items.sort((a, b) {
      final aTime = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return items;
  }

  /// [CREATE] Tambah satu kartu ke Watchlist beserta target harga opsional (`alertPriceIdr`).
  static Future<void> addToWatchlist(
    String userId,
    String cardId, {
    double? alertPriceIdr,
  }) async {
    final key = '${userId}_$cardId';
    final item = WatchlistItemModel(
      cardId: cardId,
      userId: userId,
      alertPriceIdr: alertPriceIdr,
      addedAt: DateTime.now().toUtc(),
    );
    await HiveDatabase.watchlistBox.put(key, item.toMap());
  }

  /// [CREATE BATCH] Tambah banyak kartu ke Watchlist sekaligus (Mode Pilih Multi-Select Dex).
  /// Mengembalikan jumlah kartu baru yang ditambahkan (tidak menimpa yang sudah ada).
  static Future<int> addMultipleToWatchlist(
    String userId,
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) return 0;

    int newlyAdded = 0;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final cardId in cardIds) {
      final key = '${userId}_$cardId';
      if (!HiveDatabase.watchlistBox.containsKey(key)) {
        await HiveDatabase.watchlistBox.put(key, {
          'id': key,
          'user_id': userId,
          'card_id': cardId,
          'alert_price_idr': null,
          'added_at': nowMs,
        });
        newlyAdded++;
      }
    }

    return newlyAdded;
  }

  /// [UPDATE] Perbarui target harga pengingat (`alertPriceIdr`) kartu di Watchlist.
  static Future<void> updateAlertPrice(
    String userId,
    String cardId,
    double? alertPriceIdr,
  ) async {
    final key = '${userId}_$cardId';
    final raw = HiveDatabase.watchlistBox.get(key);
    if (raw == null || raw is! Map) return;

    final map = HiveDatabase.readMap(raw);
    map['alert_price_idr'] = alertPriceIdr;
    await HiveDatabase.watchlistBox.put(key, map);
  }

  /// [DELETE] Hapus kartu dari Watchlist.
  static Future<void> removeFromWatchlist(String userId, String cardId) async {
    final key = '${userId}_$cardId';
    await HiveDatabase.watchlistBox.delete(key);
  }
}
