import 'package:uuid/uuid.dart';

import '../database/hive_database.dart';
import '../models/card_model.dart';
import '../models/listing_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'collection_repository.dart';
import 'notification_service.dart';

/// Custom Exception untuk operasi Pesanan / Rekber.
class OrderFailure implements Exception {
  final String message;
  final String? errorCode;

  const OrderFailure(this.message, [this.errorCode]);

  @override
  String toString() => message;
}

/// Repository terpusat untuk alur Rekber / Escrow COD HoloDex v2 berbasis Hive (`holodex_orders`).
/// Mengelola pemesanan listing (`reserveListing`), penahanan saldo 72 jam,
/// konfirmasi serah terima COD (`confirmReceipt`), pembatalan (`cancelOrder`),
/// serta otorisasi privasi kontak WhatsApp (`getOrderContact`).
class OrderRepository {
  OrderRepository._();

  static const _uuid = Uuid();

  /// Memetakan kode kesalahan ke pesan ramah bahasa Indonesia untuk pengguna
  static String mapErrorCodeToMessage(String? errorCode, [String? fallback]) {
    switch (errorCode) {
      case 'INSUFFICIENT_BALANCE':
        return 'Saldo virtual Anda tidak mencukupi untuk memesan kartu ini. Silakan top up terlebih dahulu.';
      case 'ALREADY_RESERVED':
        return 'Kartu ini sedang dipesan oleh kolektor lain.';
      case 'LISTING_NOT_ACTIVE':
        return 'Listing kartu sudah tidak tersedia atau telah terjual.';
      case 'CANNOT_BUY_OWN_LISTING':
        return 'Anda tidak dapat memesan kartu dari listing milik sendiri.';
      case 'ORDER_NOT_FOUND':
        return 'Data pesanan tidak ditemukan di sistem.';
      case 'UNAUTHORIZED':
        return 'Anda tidak memiliki hak untuk melakukan tindakan ini.';
      case 'INVALID_ORDER_STATUS':
        return 'Status pesanan sudah berubah (mungkin telah dibatalkan atau selesai).';
      case 'whatsapp_required':
        return 'Nomor WhatsApp wajib diisi terlebih dahulu sebelum melanjutkan transaksi agar dapat berkoordinasi COD.';
      case 'not_allowed':
        return 'Kontak WhatsApp hanya dapat diakses saat status pesanan masih aktif (Dipesan).';
      case 'no_contact':
        return 'Pihak lawan belum mengisi nomor WhatsApp.';
      case 'INVALID_PHONE_NUMBER':
        return 'Format nomor WhatsApp tidak valid. Gunakan format nomor Indonesia (contoh: 081234567890).';
      case 'ORDER_EXPIRED':
        return 'Waktu pesanan ini telah melewati batas 72 jam dan telah kedaluwarsa.';
      case 'BUYER_NOT_FOUND':
        return 'Akun pembeli tidak valid atau tidak ditemukan.';
      case 'LISTING_NOT_FOUND':
        return 'Listing kartu tidak ditemukan.';
      default:
        return fallback ??
            'Terjadi kesalahan pada transaksi. Silakan coba lagi.';
    }
  }

  /// Otomatis membatalkan pesanan yang telah melewati batas waktu 72 jam (`expiresAt`),
  /// mengembalikan saldo pembeli 100%, dan mengaktifkan kembali listing.
  static Future<int> expireStaleOrders([DateTime? currentTime]) async {
    final now = (currentTime ?? DateTime.now()).toUtc();
    int expiredCount = 0;

    for (final raw in HiveDatabase.ordersBox.values.toList()) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      if (map['status'] != 'reserved') continue;

      final expiresAt = DateTime.tryParse(map['expires_at']?.toString() ?? '');
      if (expiresAt != null && now.isAfter(expiresAt)) {
        final orderId = map['id'] as String;
        final buyerId = map['buyer_id'] as String;
        final listingId = map['listing_id'] as String;
        final amount = (map['amount_idr'] as num?)?.toDouble() ?? 0.0;

        // 1. Kembalikan saldo ke pembeli
        final buyer = await AuthService.getUserById(buyerId);
        if (buyer != null) {
          await AuthService.setUserBalance(buyerId, buyer.balanceIdr + amount);
        }

        // 2. Aktifkan kembali listing jika masih reserved
        final rawListing = HiveDatabase.listingsBox.get(listingId);
        if (rawListing is Map) {
          final lMap = HiveDatabase.readMap(rawListing);
          if (lMap['status'] == 'reserved') {
            lMap['status'] = 'active';
            lMap['updated_at'] = now.toIso8601String();
            await HiveDatabase.listingsBox.put(listingId, lMap);
          }
        }

        // 3. Tandai order sebagai expired
        map['status'] = 'expired';
        map['cancelled_at'] = now.toIso8601String();
        map['cancel_reason'] = 'Kedaluwarsa otomatis (> 72 jam)';
        await HiveDatabase.ordersBox.put(orderId, map);
        expiredCount++;
      }
    }

    return expiredCount;
  }

  /// [CREATE ORDER] Memesan listing (`reserve`) dan menahan saldo pembeli selama 72 jam di Hive.
  static Future<Map<String, dynamic>> reserveListing({
    required String listingId,
    required String buyerId,
  }) async {
    await expireStaleOrders();

    final rawListing = HiveDatabase.listingsBox.get(listingId);
    if (rawListing == null || rawListing is! Map) {
      throw OrderFailure(
        mapErrorCodeToMessage('LISTING_NOT_FOUND'),
        'LISTING_NOT_FOUND',
      );
    }

    final listingMap = HiveDatabase.readMap(rawListing);
    final status = listingMap['status'] as String? ?? 'active';
    if (status == 'reserved') {
      throw OrderFailure(
        mapErrorCodeToMessage('ALREADY_RESERVED'),
        'ALREADY_RESERVED',
      );
    }
    if (status != 'active') {
      throw OrderFailure(
        mapErrorCodeToMessage('LISTING_NOT_ACTIVE'),
        'LISTING_NOT_ACTIVE',
      );
    }

    final sellerId = listingMap['seller_id'] as String;
    if (sellerId == buyerId) {
      throw OrderFailure(
        mapErrorCodeToMessage('CANNOT_BUY_OWN_LISTING'),
        'CANNOT_BUY_OWN_LISTING',
      );
    }

    final buyer = await AuthService.getUserById(buyerId);
    if (buyer == null) {
      throw OrderFailure(
        mapErrorCodeToMessage('BUYER_NOT_FOUND'),
        'BUYER_NOT_FOUND',
      );
    }

    if (buyer.whatsappNumber == null || buyer.whatsappNumber!.trim().isEmpty) {
      throw OrderFailure(
        mapErrorCodeToMessage('whatsapp_required'),
        'whatsapp_required',
      );
    }

    final priceIdr = (listingMap['price_idr'] as num?)?.toDouble() ?? 0.0;
    if (buyer.balanceIdr < priceIdr) {
      throw OrderFailure(
        mapErrorCodeToMessage('INSUFFICIENT_BALANCE'),
        'INSUFFICIENT_BALANCE',
      );
    }

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(hours: 72));
    final orderId = 'order-${_uuid.v4().substring(0, 8)}';
    final remainingBalance = buyer.balanceIdr - priceIdr;

    // 1. Tahan (potong) saldo pembeli
    await AuthService.setUserBalance(buyerId, remainingBalance);

    // 2. Ubah status listing menjadi 'reserved'
    listingMap['status'] = 'reserved';
    listingMap['updated_at'] = now.toIso8601String();
    await HiveDatabase.listingsBox.put(listingId, listingMap);

    // 3. Simpan pesanan baru ke holodex_orders
    final cardId = listingMap['card_id'] as String;
    final orderMap = <String, dynamic>{
      'id': orderId,
      'listing_id': listingId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'card_id': cardId,
      'amount_idr': priceIdr,
      'status': OrderStatus.reserved.toDbString(),
      'reserved_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
    await HiveDatabase.ordersBox.put(orderId, orderMap);

    return {
      'ok': true,
      'order_id': orderId,
      'listing_id': listingId,
      'amount_idr': priceIdr,
      'remaining_balance': remainingBalance,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// [UPDATE ORDER] Konfirmasi serah terima COD oleh pembeli:
  /// - Menyerahkan saldo tertahan ke penjual
  /// - Memindahkan kartu fisik ke Binder Koleksi Saya milik pembeli (`holodex_collections`)
  /// - Mencatat riwayat transaksi selesai di `holodex_transactions`
  static Future<Map<String, dynamic>> confirmReceipt({
    required String orderId,
    required String buyerId,
  }) async {
    await expireStaleOrders();

    final rawOrder = HiveDatabase.ordersBox.get(orderId);
    if (rawOrder == null || rawOrder is! Map) {
      throw OrderFailure(
        mapErrorCodeToMessage('ORDER_NOT_FOUND'),
        'ORDER_NOT_FOUND',
      );
    }

    final orderMap = HiveDatabase.readMap(rawOrder);
    if (orderMap['buyer_id'] != buyerId) {
      throw OrderFailure(
        mapErrorCodeToMessage('UNAUTHORIZED'),
        'UNAUTHORIZED',
      );
    }

    final status = OrderStatus.fromString(orderMap['status'] as String?);
    if (status == OrderStatus.completed) {
      // Idempoten: jika sudah completed, kembalikan sukses tanpa menggandakan saldo
      return {
        'ok': true,
        'order_id': orderId,
        'already_completed': true,
      };
    }
    if (status == OrderStatus.expired) {
      throw OrderFailure(
        mapErrorCodeToMessage('ORDER_EXPIRED'),
        'ORDER_EXPIRED',
      );
    }
    if (status != OrderStatus.reserved) {
      throw OrderFailure(
        mapErrorCodeToMessage('INVALID_ORDER_STATUS'),
        'INVALID_ORDER_STATUS',
      );
    }

    final sellerId = orderMap['seller_id'] as String;
    final listingId = orderMap['listing_id'] as String;
    final cardId = orderMap['card_id'] as String;
    final amountIdr = (orderMap['amount_idr'] as num?)?.toDouble() ?? 0.0;
    final now = DateTime.now().toUtc();

    // 1. Tambahkan saldo ke akun penjual
    final seller = await AuthService.getUserById(sellerId);
    if (seller != null) {
      await AuthService.setUserBalance(sellerId, seller.balanceIdr + amountIdr);
    }

    // 2. Tandai listing sebagai 'sold'
    final rawListing = HiveDatabase.listingsBox.get(listingId);
    if (rawListing is Map) {
      final lMap = HiveDatabase.readMap(rawListing);
      lMap['status'] = 'sold';
      lMap['updated_at'] = now.toIso8601String();
      await HiveDatabase.listingsBox.put(listingId, lMap);
    }

    // 3. Tandai order sebagai 'completed'
    orderMap['status'] = OrderStatus.completed.toDbString();
    orderMap['completed_at'] = now.toIso8601String();
    await HiveDatabase.ordersBox.put(orderId, orderMap);

    // 4. Pindahkan kartu fisik ke Binder Koleksi pembeli & hapus dari penjual
    await CollectionRepository.addCardToCollection(
      userId: buyerId,
      cardId: cardId,
      acquiredVia: 'purchase',
    );
    await CollectionRepository.removeCardFromCollection(
      userId: sellerId,
      cardId: cardId,
    );

    // 5. Catat di holodex_transactions
    final buyer = await AuthService.getUserById(buyerId);
    CardModel? card;
    final rawCard = HiveDatabase.cardsBox.get(cardId);
    if (rawCard is Map) {
      card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
    }

    final txId = 'tx-${_uuid.v4().substring(0, 8)}';
    final tx = TransactionModel(
      id: txId,
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
      cardId: cardId,
      priceIdr: amountIdr,
      createdAt: now,
      card: card,
      buyerUsername: buyer?.username,
      sellerUsername: seller?.username,
      isBuyer: true,
    );
    await HiveDatabase.transactionsBox.put(txId, tx.toMap());

    // 6. Tampilkan notifikasi lokal transaksi selesai
    await NotificationService.instance.showInstantNotification(
      id: orderId.hashCode.abs(),
      title: 'Serah Terima COD Selesai!',
      body:
          'Kartu ${card?.name ?? cardId} telah resmi masuk ke Binder Koleksi Saya.',
      channelId: NotificationService.channelMarketplace,
    );

    return {
      'ok': true,
      'order_id': orderId,
      'transaction_id': txId,
      'card_id': cardId,
      'amount_idr': amountIdr,
    };
  }

  /// [UPDATE ORDER] Membatalkan pesanan oleh pembeli atau penjual (saldo dikembalikan 100% ke pembeli).
  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String userId,
    String? reason,
  }) async {
    await expireStaleOrders();

    final rawOrder = HiveDatabase.ordersBox.get(orderId);
    if (rawOrder == null || rawOrder is! Map) {
      throw OrderFailure(
        mapErrorCodeToMessage('ORDER_NOT_FOUND'),
        'ORDER_NOT_FOUND',
      );
    }

    final orderMap = HiveDatabase.readMap(rawOrder);
    final buyerId = orderMap['buyer_id'] as String;
    final sellerId = orderMap['seller_id'] as String;

    if (userId != buyerId && userId != sellerId) {
      throw OrderFailure(
        mapErrorCodeToMessage('UNAUTHORIZED'),
        'UNAUTHORIZED',
      );
    }

    final status = OrderStatus.fromString(orderMap['status'] as String?);
    if (status != OrderStatus.reserved) {
      throw OrderFailure(
        mapErrorCodeToMessage('INVALID_ORDER_STATUS'),
        'INVALID_ORDER_STATUS',
      );
    }

    final listingId = orderMap['listing_id'] as String;
    final amountIdr = (orderMap['amount_idr'] as num?)?.toDouble() ?? 0.0;
    final now = DateTime.now().toUtc();

    // 1. Kembalikan saldo utuh ke pembeli
    final buyer = await AuthService.getUserById(buyerId);
    final refundedBalance = (buyer?.balanceIdr ?? 0.0) + amountIdr;
    await AuthService.setUserBalance(buyerId, refundedBalance);

    // 2. Aktifkan kembali listing di Pasar
    final rawListing = HiveDatabase.listingsBox.get(listingId);
    if (rawListing is Map) {
      final lMap = HiveDatabase.readMap(rawListing);
      lMap['status'] = 'active';
      lMap['updated_at'] = now.toIso8601String();
      await HiveDatabase.listingsBox.put(listingId, lMap);
    }

    // 3. Tandai pesanan sebagai cancelled
    orderMap['status'] = OrderStatus.cancelled.toDbString();
    orderMap['cancelled_at'] = now.toIso8601String();
    orderMap['cancelled_by'] = userId;
    if (reason != null && reason.trim().isNotEmpty) {
      orderMap['cancel_reason'] = reason.trim();
    }
    await HiveDatabase.ordersBox.put(orderId, orderMap);

    return {
      'ok': true,
      'order_id': orderId,
      'refunded_amount': amountIdr,
      'remaining_balance': refundedBalance,
    };
  }

  /// [READ] Mengambil seluruh daftar pesanan (pembelian & penjualan) milik pengguna dari `holodex_orders` Hive Box.
  static Future<List<OrderModel>> getMyOrders(String userId) async {
    await expireStaleOrders();

    final list = <OrderModel>[];

    for (final raw in HiveDatabase.ordersBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      final buyerId = map['buyer_id'] as String?;
      final sellerId = map['seller_id'] as String?;

      if (buyerId != userId && sellerId != userId) continue;

      final isBuyer = buyerId == userId;
      final otherPartyId = isBuyer ? sellerId : buyerId;
      UserModel? otherUser;
      if (otherPartyId != null) {
        otherUser = await AuthService.getUserById(otherPartyId);
      }

      final cardId = map['card_id'] as String? ?? '';
      CardModel? card;
      final rawCard = HiveDatabase.cardsBox.get(cardId);
      if (rawCard is Map) {
        card = CardModel.fromMap(HiveDatabase.readMap(rawCard));
      }

      final listingId = map['listing_id'] as String? ?? '';
      ListingModel? listing;
      final rawListing = HiveDatabase.listingsBox.get(listingId);
      if (rawListing is Map) {
        listing = ListingModel.fromMap(HiveDatabase.readMap(rawListing))
            .copyWith(card: card);
      }

      final hydratedMap = <String, dynamic>{
        ...map,
        'is_buyer': isBuyer,
        'other_party_username': otherUser?.username,
        'other_party_photo_url': otherUser?.photoUrl,
        if (card != null) 'card': card.toMap(),
        if (listing != null) 'listing': listing.toMap(),
      };

      list.add(OrderModel.fromMap(hydratedMap));
    }

    list.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
    return list;
  }

  /// Menghitung total saldo pengguna yang sedang ditahan pada pesanan aktif (`reserved`).
  static Future<double> getHeldEscrowBalance(String userId) async {
    double held = 0.0;
    for (final raw in HiveDatabase.ordersBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      if (map['buyer_id'] == userId && map['status'] == 'reserved') {
        held += (map['amount_idr'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return held;
  }

  /// [OTORISASI PRIVASI WHATSAPP] Mengambil kontak WhatsApp pihak lawan
  /// HANYA jika pemanggil adalah pembeli/penjual sah DAN status pesanan masih `'reserved'`.
  static Future<OrderContactResult> getOrderContact({
    required String orderId,
    required String userId,
  }) async {
    await expireStaleOrders();

    final rawOrder = HiveDatabase.ordersBox.get(orderId);
    if (rawOrder == null || rawOrder is! Map) {
      return OrderContactResult(
        ok: false,
        orderId: orderId,
        errorCode: 'ORDER_NOT_FOUND',
        message: mapErrorCodeToMessage('ORDER_NOT_FOUND'),
      );
    }

    final map = HiveDatabase.readMap(rawOrder);
    final buyerId = map['buyer_id'] as String?;
    final sellerId = map['seller_id'] as String?;

    if (userId != buyerId && userId != sellerId) {
      return OrderContactResult(
        ok: false,
        orderId: orderId,
        errorCode: 'UNAUTHORIZED',
        message: mapErrorCodeToMessage('UNAUTHORIZED'),
      );
    }

    final status = map['status'] as String?;
    if (status != 'reserved') {
      return OrderContactResult(
        ok: false,
        orderId: orderId,
        errorCode: 'not_allowed',
        message: mapErrorCodeToMessage('not_allowed'),
      );
    }

    final isBuyer = userId == buyerId;
    final counterpartId = isBuyer ? sellerId : buyerId;
    final counterpart = counterpartId != null
        ? await AuthService.getUserById(counterpartId)
        : null;

    if (counterpart == null ||
        counterpart.whatsappNumber == null ||
        counterpart.whatsappNumber!.trim().isEmpty) {
      return OrderContactResult(
        ok: false,
        orderId: orderId,
        errorCode: 'no_contact',
        message: mapErrorCodeToMessage('no_contact'),
      );
    }

    return OrderContactResult(
      ok: true,
      orderId: orderId,
      role: isBuyer ? 'seller' : 'buyer',
      displayName: counterpart.username,
      whatsappNumber: counterpart.whatsappNumber,
    );
  }

  /// Menyimpan atau menghapus nomor WhatsApp pengguna milik sendiri di `holodex_users` Hive Box.
  static Future<String?> setMyWhatsapp({
    required String userId,
    required String? phoneNumber,
  }) async {
    try {
      return await AuthService.setMyWhatsapp(
        userId: userId,
        phoneNumber: phoneNumber,
      );
    } on AuthFailure catch (e) {
      throw OrderFailure(e.message, 'INVALID_PHONE_NUMBER');
    }
  }
}

/// Model hasil pemanggilan kontak pesanan
class OrderContactResult {
  final bool ok;
  final String? orderId;
  final String? role;
  final String? displayName;
  final String? whatsappNumber;
  final String? errorCode;
  final String? message;

  const OrderContactResult({
    required this.ok,
    this.orderId,
    this.role,
    this.displayName,
    this.whatsappNumber,
    this.errorCode,
    this.message,
  });

  factory OrderContactResult.fromJson(Map<String, dynamic> json) =>
      OrderContactResult(
        ok: json['ok'] == true,
        orderId: json['order_id'] as String?,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
        whatsappNumber: json['whatsapp_number'] as String?,
        errorCode: json['error_code'] as String?,
        message: json['error'] as String? ?? json['message'] as String?,
      );
}
