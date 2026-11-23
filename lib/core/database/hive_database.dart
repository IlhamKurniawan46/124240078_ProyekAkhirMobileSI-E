import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class HiveDatabase {
  HiveDatabase._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Daftar lengkap 10 nama Hive Box di HoloDex
  static const List<String> allBoxNames = [
    AppConstants.settingsBoxName,
    AppConstants.sessionBoxName,
    AppConstants.usersBoxName,
    AppConstants.cardsBoxName,
    AppConstants.currencyBoxName,
    AppConstants.listingsBoxName,
    AppConstants.ordersBoxName,
    AppConstants.transactionsBoxName,
    AppConstants.collectionsBoxName,
    AppConstants.watchlistBoxName,
  ];

  /// Inisialisasi Hive (mendukung `customPath` untuk unit test murni Dart)
  static Future<void> init({String? customPath}) async {
    if (_isInitialized) return;

    if (customPath != null && customPath.isNotEmpty) {
      Hive.init(customPath);
    } else {
      await Hive.initFlutter();
    }

    for (final boxName in allBoxNames) {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<dynamic>(boxName);
      }
    }

    _isInitialized = true;
  }

  // Getters untuk ke-10 Hive Box
  static Box<dynamic> get settingsBox =>
      Hive.box<dynamic>(AppConstants.settingsBoxName);
  static Box<dynamic> get sessionBox =>
      Hive.box<dynamic>(AppConstants.sessionBoxName);
  static Box<dynamic> get usersBox =>
      Hive.box<dynamic>(AppConstants.usersBoxName);
  static Box<dynamic> get cardsBox =>
      Hive.box<dynamic>(AppConstants.cardsBoxName);
  static Box<dynamic> get currencyBox =>
      Hive.box<dynamic>(AppConstants.currencyBoxName);
  static Box<dynamic> get listingsBox =>
      Hive.box<dynamic>(AppConstants.listingsBoxName);
  static Box<dynamic> get ordersBox =>
      Hive.box<dynamic>(AppConstants.ordersBoxName);
  static Box<dynamic> get transactionsBox =>
      Hive.box<dynamic>(AppConstants.transactionsBoxName);
  static Box<dynamic> get collectionsBox =>
      Hive.box<dynamic>(AppConstants.collectionsBoxName);
  static Box<dynamic> get watchlistBox =>
      Hive.box<dynamic>(AppConstants.watchlistBoxName);

  /// Helper untuk mengonversi `Map<dynamic, dynamic>` dari Hive menjadi `Map<String, dynamic>` secara rekursif.
  static Map<String, dynamic> readMap(dynamic raw) {
    if (raw == null || raw is! Map) return <String, dynamic>{};
    final result = <String, dynamic>{};
    raw.forEach((key, value) {
      final strKey = key.toString();
      if (value is Map) {
        result[strKey] = readMap(value);
      } else if (value is List) {
        result[strKey] = value
            .map((item) => item is Map ? readMap(item) : item)
            .toList();
      } else {
        result[strKey] = value;
      }
    });
    return result;
  }

  /// Mengosongkan isi seluruh 10 Hive Box (berguna untuk reset data atau unit test).
  static Future<void> clearAll() async {
    for (final boxName in allBoxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<dynamic>(boxName).clear();
      }
    }
  }

  /// Menutup seluruh Hive Box.
  static Future<void> closeAll() async {
    await Hive.close();
    _isInitialized = false;
  }
}
