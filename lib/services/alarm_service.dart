import 'dart:convert';
import 'dart:typed_data';

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
/// Doses ring like a clock alarm even when the app is backgrounded or killed:
/// the notification uses a full-screen intent (Android) that opens the alarm
/// UI over the lock screen via [onOpenAlarm] / [consumeInitialPayload].
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

  /// Launch details captured on cold start, when the app was (re)launched by
  /// the OS to deliver a full-screen alarm.
  static NotificationAppLaunchDetails? _launchDetails;

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
      debugPrint('Verifi: timezone lookup failed — $e');
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

    try {
      _launchDetails = await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Verifi: launch-details lookup failed — $e');
    }
  }

  /// The payload the app was launched with (full-screen alarm on cold start),
  /// decoded and cleared so it is only consumed once.
  static ({String medicationId, String? time})? consumeInitialPayload() {
    final payload = _launchDetails?.notificationResponse?.payload;
    _launchDetails = null;
    return payload == null ? null : _decodePayload(payload);
  }

  static ({String medicationId, String? time})? _decodePayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final medicationId = map['medicationId'] as String?;
      if (medicationId == null) return null;
      return (medicationId: medicationId, time: map['time'] as String?);
    } catch (_) {
      return null;
    }
  }

  static void _onResponse(NotificationResponse response) {
    _dispatch(response.payload);
  }

  static void _dispatch(String? payload) {
    if (payload == null) return;
    final decoded = _decodePayload(payload);
    if (decoded != null) onOpenAlarm?.call(decoded.medicationId, decoded.time);
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
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 400, 600]),
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
