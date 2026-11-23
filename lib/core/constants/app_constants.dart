class AppConstants {
  // Nama & Info App
  static const String appName = 'HoloDex';
  static const String appVersion = '2.0.0';

  // Disclaimer Akademis
  static const String academicDisclaimer =
      'HoloDex tidak berafiliasi dengan Nintendo, The Pokémon Company, atau TCGplayer. '
      'Nama dan gambar Pokémon adalah merek dagang pemiliknya. '
      'Aplikasi ini dibuat semata-mata untuk tujuan akademis (Tugas Praktikum Pemrograman Aplikasi Mobile).';

  // API Endpoints
  static const String tcgdexBaseUrl = 'https://api.tcgdex.net/v2/en';
  static const String frankfurterBaseUrl = 'https://api.frankfurter.dev';

  // Hive Box Names
  static const String settingsBoxName = 'holodex_settings';
  static const String sessionBoxName = 'holodex_session';
  static const String usersBoxName = 'holodex_users';
  static const String cardsBoxName = 'holodex_cards';
  static const String currencyBoxName = 'holodex_currency';
  static const String listingsBoxName = 'holodex_listings';
  static const String ordersBoxName = 'holodex_orders';
  static const String transactionsBoxName = 'holodex_transactions';
  static const String collectionsBoxName = 'holodex_collections';
  static const String watchlistBoxName = 'holodex_watchlist';

  // Nilai Awal Saldo Baru (Simulasi)
  static const double initialBalanceIdr = 2500000.0;
}
