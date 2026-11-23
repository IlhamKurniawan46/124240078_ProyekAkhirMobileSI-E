import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app_state.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/core/services/auth_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('holodex_auth_test_');
    await HiveDatabase.init(customPath: tempDir.path);
  });

  setUp(() async {
    await HiveDatabase.clearAll();
    await InitialDataSeeder.seedIfNeeded();
    AppState.instance.setUser(null);
  });

  tearDownAll(() async {
    await HiveDatabase.closeAll();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Sesi 3 — AuthService (SHA-256 + Persistent Session Hive)', () {
    test('Login dengan akun demo trainer_ash / password123 berhasil dan menyimpan session', () async {
      final user = await AuthService.login(
        username: 'trainer_ash',
        password: 'password123',
      );

      expect(user.username, 'trainer_ash');
      expect(user.balanceIdr, 2500000.0);
      expect(AppState.instance.currentUser.value?.id, user.id);

      // Verifikasi persistent session saat aplikasi dibuka ulang
      AppState.instance.setUser(null);
      final restored = await AuthService.restoreSession();
      expect(restored, isTrue);
      expect(AppState.instance.currentUser.value?.username, 'trainer_ash');
    });

    test('Login gagal dengan pesan AuthFailure jika password salah atau username tidak ada', () async {
      expect(
        () => AuthService.login(
          username: 'trainer_ash',
          password: 'wrongpassword',
        ),
        throwsA(isA<AuthFailure>()),
      );

      expect(
        () => AuthService.login(
          username: 'unknown_user',
          password: 'password123',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('Register akun baru menyimpan hash SHA-256, mencegah duplikat, dan auto-login', () async {
      final newUser = await AuthService.register(
        username: 'Gary_Oak',
        email: 'gary@pallet.id',
        password: 'secretpassword',
      );

      expect(newUser.username, 'Gary_Oak');
      expect(AppState.instance.currentUser.value?.id, newUser.id);

      // Pastikan password disimpan sebagai hash SHA-256 (64 karakter hex), bukan plaintext
      final stored = HiveDatabase.readMap(
        HiveDatabase.usersBox.get(newUser.id),
      );
      expect(stored['password_hash'], isNot('secretpassword'));
      expect((stored['password_hash'] as String).length, 64);

      // Duplikasi username ditolak
      expect(
        () => AuthService.register(
          username: 'gary_oak',
          email: 'other@pallet.id',
          password: 'secretpassword',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('TopUp saldo, update WhatsApp, dan Logout bekerja dengan benar di Hive', () async {
      final user = await AuthService.login(
        username: 'trainer_ash',
        password: 'password123',
      );

      final newBalance = await AuthService.topUpBalance(
        userId: user.id,
        amountIdr: 500000.0,
      );
      expect(newBalance, 3000000.0);
      expect(AppState.instance.currentUser.value?.balanceIdr, 3000000.0);

      final normalizedWa = await AuthService.setMyWhatsapp(
        userId: user.id,
        phoneNumber: '0813-9999-8888',
      );
      expect(normalizedWa, '6281399998888');
      expect(AppState.instance.currentUser.value?.whatsappNumber, '6281399998888');

      await AuthService.logout();
      expect(AppState.instance.currentUser.value, isNull);
      expect(await AuthService.restoreSession(), isFalse);
    });
  });
}
