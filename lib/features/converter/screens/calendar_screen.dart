import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/hive_database.dart';
import '../../../core/models/release_event_model.dart';
import '../../../core/services/notification_service.dart';

/// Filter kategori event di layar Event dan Pengingat.
enum EventFilter {
  all('Semua Event'),
  setRelease('Rilis Set'),
  tournament('Turnamen');

  final String label;
  const EventFilter(this.label);
}

/// Ticker detik terisolasi menggunakan `ValueNotifier<DateTime>` agar pembaruan
/// hitung mundur setiap detik HANYA me-rebuild digit countdown, bukan seluruh layar.
class ClockTicker {
  static final ValueNotifier<DateTime> liveTimeNotifier =
      ValueNotifier<DateTime>(DateTime.now());
  static Timer? _timer;
  static int _refCount = 0;

  static void start() {
    _refCount++;
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        liveTimeNotifier.value = DateTime.now();
      });
    }
  }

  static void stop() {
    _refCount--;
    if (_refCount <= 0) {
      _timer?.cancel();
      _timer = null;
      _refCount = 0;
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<ReleaseEventModel> _allEvents = [];
  EventFilter _filter = EventFilter.all;

  @override
  void initState() {
    super.initState();
    ClockTicker.start();
    _loadEvents();
  }

  @override
  void dispose() {
    ClockTicker.stop();
    super.dispose();
  }

  void _loadEvents() {
    List<ReleaseEventModel> loaded = [];
    if (Hive.isBoxOpen(AppConstants.settingsBoxName)) {
      final rawList = HiveDatabase.settingsBox.get('release_events');
      if (rawList is List && rawList.isNotEmpty) {
        loaded = rawList
            .whereType<Map>()
            .map((m) => ReleaseEventModel.fromJson(HiveDatabase.readMap(m)))
            .toList();
      }
    }
    if (loaded.isEmpty) {
      loaded = ReleaseEventModel.defaultEvents;
    }
    setState(() {
      _allEvents = loaded;
    });
  }

  List<ReleaseEventModel> get _filteredEvents {
    var list = _allEvents;
    if (_filter == EventFilter.setRelease) {
      list = list.where((e) => e.isSetRelease).toList();
    } else if (_filter == EventFilter.tournament) {
      list = list.where((e) => e.isTournament).toList();
    }
    final now = DateTime.now().toUtc();
    final upcoming = list.where((e) => e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final past = list.where((e) => !e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return [...upcoming, ...past];
  }

  ReleaseEventModel? get _nearestUpcomingEvent {
    final now = DateTime.now().toUtc();
    final upcoming = _allEvents.where((e) => e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    if (upcoming.isNotEmpty) return upcoming.first;
    return _allEvents.isNotEmpty ? _allEvents.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final nearestEvent = _nearestUpcomingEvent;
    final filtered = _filteredEvents;

    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLow,
        elevation: 0,
        title: const Text(
          'Event dan Pengingat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Event',
            icon: const Icon(Icons.refresh, color: AppColors.outline),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadEvents(),
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Hero Countdown Card (Event Mendatang Terdekat)
            if (nearestEvent != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _HeroCountdownCard(event: nearestEvent),
                ),
              ),

            // 2. Header Filter Kategori Event
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jadwal Event (Waktu Perangkat)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: EventFilter.values.map((filter) {
                          final isSelected = _filter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(filter.label),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _filter = filter);
                              },
                              selectedColor: AppColors.gold,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.onGold
                                    : AppColors.onSurfaceVariant,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.surfaceHigh,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Daftar Event
            if (filtered.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Tidak ada event untuk filter ini',
                    style: TextStyle(color: AppColors.outline),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _EventCard(event: filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _getHeroLabel(ReleaseEventModel event) {
  switch (event.eventType) {
    case 'set_release':
      return 'RILIS BERIKUTNYA';
    case 'tournament':
      return 'TURNAMEN BERIKUTNYA';
    default:
      return 'EVENT BERIKUTNYA';
  }
}

/// Widget Hero Countdown terisolasi untuk event mendatang terdekat
class _HeroCountdownCard extends StatelessWidget {
  final ReleaseEventModel event;

  const _HeroCountdownCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final localDate = event.eventDate.toLocal();
    final dateFormatted =
        DateFormat('dd MMM yyyy, HH:mm').format(localDate);
    final tzAbbrev = localDate.timeZoneName;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceHigh.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.isSetRelease
                      ? AppColors.gold.withValues(alpha: 0.2)
                      : AppColors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      event.isSetRelease ? Icons.style : Icons.emoji_events,
                      size: 13,
                      color:
                          event.isSetRelease ? AppColors.gold : AppColors.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getHeroLabel(event),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: event.isSetRelease
                            ? AppColors.gold
                            : AppColors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
              if (event.location != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place,
                        size: 12,
                        color: AppColors.outline,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          event.location!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dateFormatted ($tzAbbrev)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.goldSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          // Digit Hitung Mundur Terisolasi (ValueListenableBuilder)
          ValueListenableBuilder<DateTime>(
            valueListenable: ClockTicker.liveTimeNotifier,
            builder: (context, now, _) {
              final diff = event.eventDate.difference(now.toUtc());
              final isPast = diff.isNegative;
              final days = isPast ? 0 : diff.inDays;
              final hours = isPast ? 0 : diff.inHours.remainder(24);
              final minutes = isPast ? 0 : diff.inMinutes.remainder(60);
              final seconds = isPast ? 0 : diff.inSeconds.remainder(60);

              return Row(
                children: [
                  _buildCountdownBox(days.toString().padLeft(2, '0'), 'HARI'),
                  const SizedBox(width: 8),
                  _buildCountdownBox(hours.toString().padLeft(2, '0'), 'JAM'),
                  const SizedBox(width: 8),
                  _buildCountdownBox(
                    minutes.toString().padLeft(2, '0'),
                    'MENIT',
                  ),
                  const SizedBox(width: 8),
                  _buildCountdownBox(
                    seconds.toString().padLeft(2, '0'),
                    'DETIK',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu Item Event dengan waktu lokal perangkat & tombol "Ingatkan Saya"
class _EventCard extends StatelessWidget {
  final ReleaseEventModel event;

  const _EventCard({required this.event});

  void _showReminderSheet(BuildContext context) {
    final localEventDate = event.eventDate.toLocal();
    final notifId = event.id.hashCode.abs();
    final payload = jsonEncode({
      'type': 'event',
      'eventId': event.id,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Atur Pengingat Notifikasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mengikuti jam perangkat (${localEventDate.timeZoneName})',
                  style: const TextStyle(fontSize: 11, color: AppColors.outline),
                ),
                const SizedBox(height: 16),

                // Opsi 1: Jadwalkan H-1 Sebelum Event
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                      minimumSize: const Size(64, 48),
                    ),
                    icon: const Icon(Icons.alarm_add),
                    label: const Text(
                      'Ingatkan H-1 Sebelum Event',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NotificationService.instance.requestPermission();
                      final targetTime =
                          localEventDate.subtract(const Duration(days: 1));
                      final res = await NotificationService.instance
                          .scheduleEventNotification(
                        id: notifId,
                        title: 'Pengingat Besok: ${event.title}',
                        body:
                            'Jangan lewatkan ${event.title} besok pada ${DateFormat('HH:mm').format(localEventDate)}!',
                        scheduledDate: targetTime,
                        payload: payload,
                      );

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res == NotificationScheduleResult.success
                                ? 'Pengingat H-1 berhasil dijadwalkan mengikuti jam perangkat!'
                                : 'Pengingat telah diaktifkan untuk event ini.',
                          ),
                          backgroundColor: AppColors.surfaceHighest,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Opsi 2: Simulasi Demo Instan (5 Detik) untuk Praktikum
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      foregroundColor: AppColors.cyan,
                      side: const BorderSide(color: AppColors.cyan),
                    ),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text(
                      'Uji Notifikasi Sekarang (5 Detik)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NotificationService.instance.requestPermission();
                      await NotificationService.instance.scheduleDemoReminder(
                        id: notifId + 100,
                        title: 'Pengingat Event: ${event.title}',
                        body:
                            'Event segera dimulai di ${event.location ?? 'HoloDex'}!',
                        delaySeconds: 5,
                        payload: payload,
                      );

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notifikasi akan muncul dalam 5 detik...',
                          ),
                          backgroundColor: AppColors.surfaceHighest,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localDate = event.eventDate.toLocal();
    final dateStr = DateFormat('dd MMM yyyy').format(localDate);
    final timeStr = DateFormat('HH:mm').format(localDate);
    final tzAbbrev = localDate.timeZoneName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.isSetRelease
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.isSetRelease ? 'Rilis Set' : 'Turnamen',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: event.isSetRelease ? AppColors.gold : AppColors.cyan,
                  ),
                ),
              ),
              Text(
                '$dateStr • $timeStr ($tzAbbrev)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          if (event.location != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 13, color: AppColors.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 42),
                foregroundColor: AppColors.gold,
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showReminderSheet(context),
              icon: const Icon(Icons.notifications_none, size: 17),
              label: const Text(
                'Ingatkan Saya',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
