import '../models/card_model.dart';
import '../services/currency_service.dart';
import 'price_formatter.dart';

/// 4 mata uang resmi yang didukung HoloDex (IDR default + USD, EUR, JPY).
enum AppCurrency {
  idr('IDR', 'Rp', 'Rupiah (IDR)'),
  usd('USD', r'$', 'US Dollar (USD)'),
  eur('EUR', '€', 'Euro (EUR)'),
  jpy('JPY', '¥', 'Yen Jepang (JPY)');

  final String code;
  final String symbol;
  final String label;

  const AppCurrency(this.code, this.symbol, this.label);

  static AppCurrency fromCode(String? code) {
    if (code == null) return AppCurrency.idr;
    final upper = code.trim().toUpperCase();
    for (final c in AppCurrency.values) {
      if (c.code == upper) return c;
    }
    return AppCurrency.idr;
  }
}

/// Helper terpusat untuk kalkulasi dan format harga kartu Pokémon
class CardPriceCalculator {
  /// Mengonversi harga acuan kartu ke mata uang target.
  /// Mengutamakan `priceRefUsd` (USD) lalu dikonversi secara live.
  static double? getConvertedPrice(CardModel card, AppCurrency targetCurrency) {
    if (card.priceRefUsd != null) {
      final converted = CurrencyService.convert(
        card.priceRefUsd!,
        from: 'USD',
        to: targetCurrency.code,
      );
      if (converted != null) return converted;
    }

    // Fallback jika priceRefUsd null atau kurs gagal dimuat
    switch (targetCurrency) {
      case AppCurrency.idr:
        return card.priceIdr;
      case AppCurrency.usd:
        return card.priceUsd ?? card.priceRefUsd;
      case AppCurrency.eur:
        return card.priceEur;
      case AppCurrency.jpy:
        if (card.priceIdr != null) {
          return CurrencyService.convert(card.priceIdr!, from: 'IDR', to: 'JPY');
        }
        return null;
    }
  }

  /// Format harga terkonversi kartu menjadi teks siap tampil.
  static String formatCardPrice(CardModel card, AppCurrency targetCurrency) {
    final price = getConvertedPrice(card, targetCurrency);
    if (price == null || price <= 0) return '-';
    return PriceFormatter.format(price, targetCurrency.code);
  }
}
