import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';

/// Schedules OS-level alarm notifications for medication doses.
///
/// Notifications ring like a clock alarm even when the app is backgrounded
/// (subject to each platform's rules) and, when tapped, open the in-app alarm
/// UI via [onOpenAlarm].
class AlarmService {
  AlarmService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Used to route a tapped notification to the alarm screen.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Invoked when the user taps a dose notification. Args: medicationId, time.
  static void Function(String medicationId, String? time)? onOpenAlarm;

  static bool _initialized = false;

  static const String _channelId = 'medication_alarms';
  static const String _channelName = 'Medication reminders';
  static const String _channelDescription =
      'Alerts when it is time to take a medication';

  static bool get isInitialized => _initialized;

  /// Initializes the plugin, device timezone, and permissions. Idempotent.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Certo: timezone lookup failed — $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static void _onResponse(NotificationResponse response) {
    _dispatch(response.payload);
  }

  static void _dispatch(String? payload) {
    if (payload == null) return;
    String? medicationId;
    String? time;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      medicationId = map['medicationId'] as String?;
      time = map['time'] as String?;
    } catch (_) {
      return;
    }
    if (medicationId != null) onOpenAlarm?.call(medicationId, time);
  }

  /// Cancels all pending notifications and schedules the next occurrences of
  /// every active medication.
  static Future<void> syncMedications(List<Medication> meds) async {
    await init();
    await _plugin.cancelAll();

    final now = DateTime.now();
    var id = 0;
    for (final m in meds) {
      if (m.status != MedicationStatus.active) continue;
      for (final at in upcomingOccurrences(m, now, days: 14)) {
        await _plugin.zonedSchedule(
          id: id++,
          title: m.name,
          body: m.dosageLine,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: jsonEncode({'medicationId': m.id, 'time': clock12(at)}),
        );
      }
    }
  }

  /// Schedules a one-off "snoozed" reminder [minutes] from now.
  static Future<void> snooze(Medication m, String time, int minutes) async {
    await init();
    final at = DateTime.now().add(Duration(minutes: minutes));
    await _plugin.zonedSchedule(
      id: _snoozeId(m.id),
      title: m.name,
      body: m.dosageLine,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'medicationId': m.id, 'time': time}),
    );
  }

  /// Cancels the one-off snooze reminder for a medication, if any.
  static Future<void> cancelSnooze(String medicationId) async {
    await init();
    await _plugin.cancel(id: _snoozeId(medicationId));
  }

  static int _snoozeId(String medicationId) {
    // Keep within the int32 notification-id range; distinct from dose ids.
    return 100000 + medicationId.hashCode.abs() % 100000;
  }

  static NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }
}
