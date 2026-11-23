import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/database/hive_database.dart';
import 'core/database/initial_data_seeder.dart';
import 'core/services/currency_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi 10 Hive Box Local Storage & Seeder Data Awal
  try {
    await HiveDatabase.init();
    await InitialDataSeeder.seedIfNeeded();
    AppState.instance.loadSavedCurrency();
  } catch (e) {
    debugPrint('[HoloDex Error] Inisialisasi HiveDatabase gagal: $e');
  }

  // 2. Inisialisasi kurs mata uang (offline-first via Hive cache + Frankfurter API)
  try {
    await CurrencyService.initRates();
  } catch (e) {
    debugPrint('[HoloDex Error] Inisialisasi CurrencyService gagal: $e');
  }

  // 3. Inisialisasi service notifikasi lokal (mengikuti jam perangkat)
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[HoloDex Error] Inisialisasi NotificationService gagal: $e');
  }

  // 4. Jalankan aplikasi Flutter (tanpa Riverpod ProviderScope)
  runApp(const HoloDexApp());
}
