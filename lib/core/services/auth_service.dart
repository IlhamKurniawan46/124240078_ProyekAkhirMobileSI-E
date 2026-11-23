import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../constants/app_constants.dart';
import '../database/hive_database.dart';
import '../models/user_model.dart';
import '../utils/whatsapp_helper.dart';

/// Custom Exception untuk kesalahan autentikasi.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// Layanan Autentikasi & Persistent Session berbasis Local Storage Hive.
/// Menggunakan hashing SHA-256 satu baris (`package:crypto`) dan menyimpan
/// sesi login aktif di `holodex_session` Hive Box.
class AuthService {
  AuthService._();

  static const _uuid = Uuid();
  static const String _sessionKey = 'current';

  /// Hash password satu baris menggunakan SHA-256 (`crypto`).
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Registrasi akun baru ke `holodex_users` Hive Box dan langsung membuat sesi login.
  static Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanUsername.length < 3) {
      throw const AuthFailure('Username minimal 3 karakter.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password minimal 6 karakter.');
    }

    // Cek duplikasi username atau email di holodex_users
    for (final raw in HiveDatabase.usersBox.values) {
      final map = HiveDatabase.readMap(raw);
      final existingUser = (map['username'] as String? ?? '').toLowerCase();
      final existingEmail = (map['email'] as String? ?? '').toLowerCase();

      if (existingUser == cleanUsername.toLowerCase()) {
        throw const AuthFailure('Username sudah digunakan. Pilih username lain.');
      }
      if (cleanEmail.isNotEmpty && existingEmail == cleanEmail) {
        throw const AuthFailure('Email sudah terdaftar.');
      }
    }

    final newUser = UserModel(
      id: 'user-${_uuid.v4().substring(0, 8)}',
      username: cleanUsername,
      email: cleanEmail,
      balanceIdr: AppConstants.initialBalanceIdr,
      createdAt: DateTime.now().toUtc(),
    );

    final userRecord = <String, dynamic>{
      ...newUser.toMap(),
      'password_hash': hashPassword(password),
    };

    await HiveDatabase.usersBox.put(newUser.id, userRecord);
    await _saveSession(newUser);
    return newUser;
  }

  /// Login pengguna dengan mencocokkan username dan hash SHA-256 password di `holodex_users`.
  static Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final inputHash = hashPassword(password);

    Map<String, dynamic>? matchedRecord;
    for (final raw in HiveDatabase.usersBox.values) {
      final map = HiveDatabase.readMap(raw);
      final existingUsername = (map['username'] as String? ?? '').toLowerCase();
      if (existingUsername == cleanUsername) {
        matchedRecord = map;
        break;
      }
    }

    if (matchedRecord == null) {
      throw const AuthFailure('Username atau password salah.');
    }

    final storedHash = matchedRecord['password_hash'] as String? ?? '';
    if (storedHash != inputHash) {
      throw const AuthFailure('Username atau password salah.');
    }

    final user = UserModel.fromMap(matchedRecord);
    await _saveSession(user);
    return user;
  }

  /// Simpan sesi aktif ke `holodex_session` Hive Box dan perbarui `AppState.instance.currentUser`.
  static Future<void> _saveSession(UserModel user) async {
    await HiveDatabase.sessionBox.put(_sessionKey, {
      'active_user_id': user.id,
      'username': user.username,
      'logged_in_at': DateTime.now().toUtc().toIso8601String(),
    });
    AppState.instance.setUser(user);
  }

  /// Memeriksa `holodex_session` saat aplikasi dibuka (`SplashScreen`).
  /// Mengembalikan `true` dan memuat `UserModel` ke `AppState` jika sesi valid.
  static Future<bool> restoreSession() async {
    final rawSession = HiveDatabase.sessionBox.get(_sessionKey);
    if (rawSession == null || rawSession is! Map) {
      AppState.instance.setUser(null);
      return false;
    }

    final sessionMap = HiveDatabase.readMap(rawSession);
    final userId = sessionMap['active_user_id'] as String?;
    if (userId == null || userId.isEmpty) {
      AppState.instance.setUser(null);
      return false;
    }

    final user = await getUserById(userId);
    if (user == null) {
      await HiveDatabase.sessionBox.clear();
      AppState.instance.setUser(null);
      return false;
    }

    AppState.instance.setUser(user);
    return true;
  }

  /// Hapus sesi login aktif dari `holodex_session` dan bersihkan `AppState.currentUser`.
  static Future<void> logout() async {
    await HiveDatabase.sessionBox.clear();
    AppState.instance.setUser(null);
  }

  /// Ambil `UserModel` berdasarkan `userId` dari `holodex_users` Hive Box.
  static Future<UserModel?> getUserById(String userId) async {
    final raw = HiveDatabase.usersBox.get(userId);
    if (raw == null || raw is! Map) return null;
    return UserModel.fromMap(HiveDatabase.readMap(raw));
  }

  /// Ambil `UserModel` berdasarkan `username` dari `holodex_users` Hive Box.
  static Future<UserModel?> getUserByUsername(String username) async {
    final target = username.trim().toLowerCase();
    for (final raw in HiveDatabase.usersBox.values) {
      final map = HiveDatabase.readMap(raw);
      if ((map['username'] as String? ?? '').toLowerCase() == target) {
        return UserModel.fromMap(map);
      }
    }
    return null;
  }

  /// Segarkan data `AppState.instance.currentUser` dari `holodex_users` Hive Box.
  static Future<UserModel?> refreshCurrentUser() async {
    final current = AppState.instance.currentUser.value;
    if (current == null) return null;
    final fresh = await getUserById(current.id);
    if (fresh != null) {
      AppState.instance.setUser(fresh);
    }
    return fresh;
  }

  /// Perbarui foto profil pengguna di `holodex_users` dan `AppState`.
  static Future<UserModel?> updateUserPhoto(
    String userId,
    String? photoPath,
  ) async {
    final raw = HiveDatabase.usersBox.get(userId);
    if (raw == null || raw is! Map) return null;
    final map = HiveDatabase.readMap(raw);
    map['photo_url'] = photoPath;
    map['photo_path'] = photoPath;
    await HiveDatabase.usersBox.put(userId, map);

    final updated = UserModel.fromMap(map);
    if (AppState.instance.currentUser.value?.id == userId) {
      AppState.instance.setUser(updated);
    }
    return updated;
  }

  /// Perbarui atau hapus nomor WhatsApp pengguna untuk koordinasi COD.
  static Future<String?> setMyWhatsapp({
    required String userId,
    String? phoneNumber,
  }) async {
    final raw = HiveDatabase.usersBox.get(userId);
    if (raw == null || raw is! Map) {
      throw const AuthFailure('Akun pengguna tidak ditemukan.');
    }

    String? normalized;
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      normalized = WhatsAppHelper.normalizePhoneId(phoneNumber);
      if (normalized == null) {
        throw const AuthFailure(
          'Format nomor WhatsApp tidak valid. Gunakan nomor Indonesia (contoh: 081234567890).',
        );
      }
    }

    final map = HiveDatabase.readMap(raw);
    map['whatsapp_number'] = normalized;
    await HiveDatabase.usersBox.put(userId, map);

    final updated = UserModel.fromMap(map);
    if (AppState.instance.currentUser.value?.id == userId) {
      AppState.instance.setUser(updated);
    }
    return normalized;
  }

  /// Tambah saldo simulasi (Top Up) untuk pengguna.
  static Future<double> topUpBalance({
    required String userId,
    required double amountIdr,
  }) async {
    if (amountIdr <= 0) {
      throw const AuthFailure('Nominal Top Up harus lebih dari Rp 0.');
    }
    final raw = HiveDatabase.usersBox.get(userId);
    if (raw == null || raw is! Map) {
      throw const AuthFailure('Akun pengguna tidak ditemukan.');
    }

    final map = HiveDatabase.readMap(raw);
    final currentBalance = (map['balance_idr'] as num?)?.toDouble() ?? 0.0;
    final newBalance = currentBalance + amountIdr;
    map['balance_idr'] = newBalance;
    await HiveDatabase.usersBox.put(userId, map);

    final updated = UserModel.fromMap(map);
    if (AppState.instance.currentUser.value?.id == userId) {
      AppState.instance.setUser(updated);
    }
    return newBalance;
  }

  /// Set saldo baru secara langsung (digunakan saat mutasi transaksi/rekber).
  static Future<void> setUserBalance(String userId, double newBalanceIdr) async {
    final raw = HiveDatabase.usersBox.get(userId);
    if (raw == null || raw is! Map) return;
    final map = HiveDatabase.readMap(raw);
    map['balance_idr'] = newBalanceIdr;
    await HiveDatabase.usersBox.put(userId, map);

    if (AppState.instance.currentUser.value?.id == userId) {
      AppState.instance.setUser(UserModel.fromMap(map));
    }
  }
}
