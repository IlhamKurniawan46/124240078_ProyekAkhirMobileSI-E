import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/database/hive_database.dart';
import 'package:holodex/core/database/initial_data_seeder.dart';
import 'package:holodex/features/converter/screens/calendar_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    final tempDir =
        await Directory.systemTemp.createTemp('holodex_calendar_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
  });

  Widget buildTestApp({double textScale = 1.0, Size size = const Size(400, 800)}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const CalendarScreen(),
      ),
    );
  }

  group('CalendarScreen (Event dan Pengingat) Widget Tests', () {
    testWidgets(
        'Menampilkan judul Event dan Pengingat, Hero Countdown, dan Daftar Event mengikuti jam perangkat',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Event dan Pengingat'), findsOneWidget);
      expect(find.text('RILIS BERIKUTNYA'), findsOneWidget);
      expect(find.text('HARI'), findsOneWidget);
      expect(find.text('JAM'), findsOneWidget);
      expect(find.text('MENIT'), findsOneWidget);
      expect(find.text('DETIK'), findsOneWidget);

      // Pastikan bagian 4 Zona Waktu (WIB/WITA/WIT/London) sudah dihapus
      expect(find.text('Jam Dunia Real-Time (4 Zona Waktu)'), findsNothing);

      // Pastikan filter kategori chip tersedia
      expect(find.text('Semua Event'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Rilis Set'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Turnamen'), findsOneWidget);
    });

    testWidgets('Filter kategori event menyaring daftar event dengan benar',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Turnamen'));
      await tester.pump();

      expect(
        find.text('Turnamen Nasional HoloDex Nusantara Cup'),
        findsWidgets,
      );
    });

    testWidgets(
        'Aman dari RenderFlex overflow pada layar sempit 320dp dengan textScaleFactor 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(textScale: 1.3, size: const Size(320, 700)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
