import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/collection_item_model.dart';
import 'package:holodex/core/models/watchlist_item_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/profile/screens/watchlist_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Collection / Koleksi Saya Unit Tests', () {
    test('CollectionItemModel serialization and defaults', () {
      final now = DateTime.now();
      final item = CollectionItemModel(
        cardId: 'swsh3-19',
        userId: 'user-uuid-1',
        acquiredVia: 'purchase',
        acquiredAt: now,
      );

      final map = item.toMap();
      expect(map['card_id'], equals('swsh3-19'));
      expect(map['user_id'], equals('user-uuid-1'));
      expect(map['acquired_via'], equals('purchase'));
      expect(map['acquired_at'], equals(now.millisecondsSinceEpoch));

      final recreated = CollectionItemModel.fromMap(map);
      expect(recreated.cardId, equals('swsh3-19'));
      expect(recreated.acquiredVia, equals('purchase'));
    });

    test('Kalkulasi nilai portofolio koleksi mengikuti kurs aktif CurrencyService', () {
      CurrencyService.setMockRates(const CurrencyRates(
        usdToEur: 0.92,
        usdToIdr: 16000.0,
        ecbDate: '2026-10-22',
      ));

      const card = CardModel(
        id: 'c1',
        name: 'Rayquaza',
        priceRefUsd: 10.0,
        hasPrice: true,
      );

      final totalIdr = CardPriceCalculator.getConvertedPrice(
        card,
        AppCurrency.idr,
      );
      expect(totalIdr, equals(160000.0));

      final totalEur = CardPriceCalculator.getConvertedPrice(
        card,
        AppCurrency.eur,
      );
      expect(totalEur, closeTo(9.20, 0.0001));

      final totalUsd = CardPriceCalculator.getConvertedPrice(
        card,
        AppCurrency.usd,
      );
      expect(totalUsd, equals(10.0));
    });
  });

  group('Watchlist Unit Tests', () {
    test('WatchlistItemModel serialization and copyWith', () {
      const item = WatchlistItemModel(
        cardId: 'swsh7-215',
        userId: 'user-uuid-1',
        alertPriceIdr: 500000.0,
      );

      final map = item.toMap();
      expect(map['card_id'], equals('swsh7-215'));
      expect(map['alert_price_idr'], equals(500000.0));

      final updated = item.copyWith(alertPriceIdr: 450000.0);
      expect(updated.alertPriceIdr, equals(450000.0));
      expect(updated.cardId, equals('swsh7-215'));
    });

    test('WatchlistScreen.isTargetReached evaluates condition accurately', () {
      CurrencyService.setMockRates(const CurrencyRates(
        usdToEur: 0.92,
        usdToIdr: 16000.0,
        ecbDate: '2026-10-22',
      ));

      const card = CardModel(
        id: 'c1',
        name: 'Gengar',
        priceRefUsd: 10.0,
        priceIdr: 160000.0,
        hasPrice: true,
      );

      // Kasus 1: Target Rp180.000 (Harga saat ini Rp160.000 <= 180.000) => TARGET TERCAPAI
      const itemReached = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: 180000.0,
        card: card,
      );
      expect(WatchlistScreen.isTargetReached(itemReached), isTrue);

      // Kasus 2: Target Rp150.000 (Harga saat ini Rp160.000 > 150.000) => BELUM TERCAPAI
      const itemNotReached = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: 150000.0,
        card: card,
      );
      expect(WatchlistScreen.isTargetReached(itemNotReached), isFalse);

      // Kasus 3: Tanpa target harga => false
      const itemNoTarget = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: null,
        card: card,
      );
      expect(WatchlistScreen.isTargetReached(itemNoTarget), isFalse);
    });
  });
}
