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
        await Directory.systemTemp.createTemp('holodex_notif_widget_test_');
    await HiveDatabase.init(customPath: tempDir.path);
    await InitialDataSeeder.seedIfNeeded();
  });

  Widget buildCalendarScreen({
    double textScale = 1.0,
    Size size = const Size(400, 800),
  }) {
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

  group('Notification Widget Tests (Calendar Screen & Anti-Overflow)', () {
    testWidgets('Menampilkan tombol Ingatkan Saya pada event kalender',
        (tester) async {
      await tester.pumpWidget(buildCalendarScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ingatkan Saya'), findsWidgets);
    });

    testWidgets('Membuka bottom sheet pengingat dan opsi simulasi demo 5 detik',
        (tester) async {
      await tester.pumpWidget(buildCalendarScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Ingatkan Saya').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Atur Pengingat Notifikasi'), findsOneWidget);
      expect(find.text('Ingatkan H-1 Sebelum Event'), findsOneWidget);
      expect(
        find.text('Uji Notifikasi Sekarang (5 Detik)'),
        findsOneWidget,
      );
    });

    testWidgets('Bebas dari overflow pada layar 320dp dan font scale 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 750 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildCalendarScreen(textScale: 1.3, size: const Size(320, 750)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('Ingatkan Saya'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Ingatkan Saya').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Atur Pengingat Notifikasi'), findsOneWidget);
    });
  });
}
