import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../app/navigation_keys.dart';
import '../../features/converter/screens/calendar_screen.dart';
import '../../features/dex/screens/card_detail_screen.dart';
import '../../features/profile/screens/watchlist_screen.dart';
import '../database/hive_database.dart';
import '../models/card_model.dart';

/// Hasil penjadwalan notifikasi
enum NotificationScheduleResult {
  success,
  pastTime,
  error,
}

/// Menggunakan `flutter_local_notifications` + `timezone` + `flutter_timezone`
/// mengikuti zona waktu perangkat (`tz.local`).
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Callback navigasi saat notifikasi ditekan
  static void Function(String? payload)? onNotificationTapped;

  // Channel IDs
  static const String channelEvents = 'holodex_events';
  static const String channelMarketplace = 'holodex_marketplace';
  static const String channelAlerts = 'holodex_alerts';

  /// Inisialisasi plugin notifikasi, channel Android, dan timezone lokal perangkat.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi timezone database & deteksi timezone perangkat
      tz.initializeTimeZones();
      await _configureLocalTimeZone();

      // 2. Pasang default handler deep-link menggunakan rootNavigatorKey
      onNotificationTapped ??= handleNotificationPayload;

      // 3. Pengaturan platform Android & iOS
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '[HoloDex Notifikasi] Notifikasi ditekan dengan payload: ${response.payload}',
          );
          onNotificationTapped?.call(response.payload);
        },
      );

      // 4. Daftarkan 3 Notification Channels di Android
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelEvents,
            'Pengingat Event Pokémon',
            description: 'Notifikasi jadwal rilis set & turnamen Pokémon TCG',
            importance: Importance.high,
            playSound: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMarketplace,
            'Transaksi Pasar HoloDex',
            description: 'Status pemesanan rekber COD dan jual-beli kartu fisik',
            importance: Importance.high,
            playSound: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAlerts,
            'Peringatan Harga Watchlist',
            description: 'Pemberitahuan saat kartu incaran mencapai target harga',
            importance: Importance.defaultImportance,
            playSound: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal inisialisasi: $e');
    }
  }

  /// Mengatur `tz.local` agar mengikuti zona waktu perangkat menggunakan `flutter_timezone`.
  Future<void> _configureLocalTimeZone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(tzInfo.identifier);
      tz.setLocalLocation(location);
    } catch (_) {
      // Fallback aman ke Asia/Jakarta jika di lingkungan test atau platform desktop
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {}
    }
  }

  /// Navigasi deep-link saat notifikasi diketuk tanpa memerlukan BuildContext (`rootNavigatorKey`).
  static void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'event' || type == 'calendar') {
        nav.push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
      } else if (type == 'card_detail' && data['cardId'] != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => CardDetailScreen(cardId: data['cardId'] as String),
          ),
        );
      } else if (type == 'watchlist') {
        nav.push(MaterialPageRoute(builder: (_) => const WatchlistScreen()));
      }
    } catch (_) {
      nav.push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    }
  }

  /// Meminta izin notifikasi (wajib untuk Android 13+ / Tiramisu)
  Future<bool> requestPermission() async {
    try {
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi] Error request permission: $e');
      return false;
    }
  }

  /// Menampilkan notifikasi instan langsung
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelMarketplace,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == channelMarketplace
            ? 'Transaksi Pasar HoloDex'
            : 'Notifikasi HoloDex',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal menampilkan instant notif: $e');
    }
  }

  /// Menjadwalkan pengingat event menggunakan zona waktu lokal perangkat (`tz.local`).
  Future<NotificationScheduleResult> scheduleEventNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? timeZoneName,
  }) async {
    try {
      tz.Location location = tz.local;
      if (timeZoneName != null && timeZoneName.isNotEmpty) {
        try {
          location = tz.getLocation(timeZoneName);
        } catch (_) {
          location = tz.local;
        }
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, location);

      if (tzScheduled.isBefore(tz.TZDateTime.now(location))) {
        return NotificationScheduleResult.pastTime;
      }

      const androidDetails = AndroidNotificationDetails(
        channelEvents,
        'Pengingat Event Pokémon',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: payload,
        );
      }

      return NotificationScheduleResult.success;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal jadwalkan notifikasi: $e');
      return NotificationScheduleResult.error;
    }
  }

  /// Menjadwalkan pengingat simulasi / demo (5 detik dari sekarang) mengikuti jam perangkat (`tz.local`).
  Future<void> scheduleDemoReminder({
    required int id,
    required String title,
    required String body,
    int delaySeconds = 5,
    String? payload,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduled = now.add(Duration(seconds: delaySeconds));

      const androidDetails = AndroidNotificationDetails(
        channelEvents,
        'Pengingat Event Pokémon',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {
        Future.delayed(Duration(seconds: delaySeconds), () {
          showInstantNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
            channelId: channelEvents,
          );
        });
      }
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal simulasi: $e');
    }
  }

  /// Membatalkan notifikasi terjadwal
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Memeriksa daftar notifikasi yang masih pending
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  /// Cek Price Alert Watchlist dari `holodex_watchlist` Hive Box.
  Future<int> checkWatchlistPriceAlerts({
    required List<CardModel> catalogCards,
  }) async {
    try {
      int triggeredCount = 0;
      final cardMap = {for (final c in catalogCards) c.id: c};

      for (final raw in HiveDatabase.watchlistBox.values) {
        if (raw is! Map) continue;
        final row = HiveDatabase.readMap(raw);
        final cardId = row['card_id'] as String?;
        final targetPrice = (row['alert_price_idr'] as num?)?.toDouble();

        if (cardId == null || targetPrice == null || targetPrice <= 0) continue;

        final card = cardMap[cardId];
        if (card != null && card.priceIdr != null) {
          final livePrice = card.priceIdr!;
          if (livePrice <= targetPrice) {
            triggeredCount++;
            final notifId = cardId.hashCode.abs();
            await showInstantNotification(
              id: notifId,
              title: 'Target Harga Tercapai: ${card.name}!',
              body:
                  'Harga pasar saat ini Rp${livePrice.round()} (Target: Rp${targetPrice.round()}). Ketuk untuk lihat kartu.',
              channelId: channelAlerts,
              payload: jsonEncode({
                'type': 'card_detail',
                'cardId': cardId,
              }),
            );
          }
        }
      }
      return triggeredCount;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal check watchlist alert: $e');
      return 0;
    }
  }
}
