import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/database/hive_database.dart';
import '../core/models/user_model.dart';
import '../core/utils/card_price_calculator.dart';

export '../core/utils/card_price_calculator.dart';

class AppState {
  AppState._();

  static final AppState instance = AppState._();

  /// Pengguna aktif yang sedang login (null jika belum login).
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  /// Mata uang pilihan yang digunakan di seluruh layar.
  final ValueNotifier<AppCurrency> selectedCurrency =
      ValueNotifier<AppCurrency>(AppCurrency.idr);

  /// Muat preferensi mata uang tersimpan dari `holodex_settings` Hive Box.
  void loadSavedCurrency() {
    if (!Hive.isBoxOpen(AppConstants.settingsBoxName)) return;
    final rawCode = HiveDatabase.settingsBox.get('selected_currency') as String?;
    selectedCurrency.value = AppCurrency.fromCode(rawCode);
  }

  /// Ubah mata uang aktif dan simpan secara persisten ke `holodex_settings` Hive Box.
  Future<void> setCurrency(AppCurrency currency) async {
    if (selectedCurrency.value == currency) return;
    selectedCurrency.value = currency;
    if (Hive.isBoxOpen(AppConstants.settingsBoxName)) {
      await HiveDatabase.settingsBox.put('selected_currency', currency.code);
    }
  }

  /// Perbarui objek pengguna aktif di memori.
  void setUser(UserModel? user) {
    currentUser.value = user;
  }
}
