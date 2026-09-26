import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import '../utils/format.dart';
import '../utils/schedule.dart';
import 'alarm_sound_service.dart';

/// Schedules OS-level alarm notifications for medication doses.
///
/// Doses ring like a clock alarm even when the app is backgrounded or killed:
/// the notification uses a full-screen intent (Android) that opens the alarm
/// UI over the lock screen via [onOpenAlarm] / [consumeInitialPayload].
///
/// Scheduling falls back to inexact alarms when the exact-alarm permission is
/// unavailable, so reminders always fire rather than failing silently. The
/// notification sound follows the user's chosen alarm ringtone (see
/// [AlarmSoundService]).
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

  /// Whether runtime permissions have been requested (activity must be live).
  static bool _permissionsRequested = false;

  /// Launch details captured on cold start, when the app was (re)launched by
  /// the OS to deliver a full-screen alarm.
  static NotificationAppLaunchDetails? _launchDetails;

  static const String _channelId = 'medication_alarms';
  static const String _channelName = 'Medication alarms';
  static const String _channelDescription =
      'Alerts when it is time to take a medication';

  /// The device's default alarm ringtone URI, resolved once at init.
  static String? _defaultAlarmUri;

  /// The user-selected alarm ringtone URI, or null to use the device default.
  static String? _alarmSoundUri;

  /// Whether the OS can currently deliver exact alarms.
  static bool _canScheduleExact = false;

  static bool get isInitialized => _initialized;

  /// Whether exact alarms are available on this device.
  static bool get canScheduleExact => _canScheduleExact;

  /// Sets the alarm ringtone used by future notifications (null = default).
  static void setAlarmSoundUri(String? uri) {
    _alarmSoundUri = (uri == null || uri.isEmpty) ? null : uri;
  }

  static String? get alarmSoundUri => _alarmSoundUri;

  /// Initializes the plugin and device timezone. Idempotent.
  ///
  /// This is safe to call from `main()` before `runApp()`: it only touches the
  /// plugin's application context. Activity-dependent setup (runtime permission
  /// requests and cold-start launch details) lives in [requestPermissions] and
  /// [captureLaunchDetails], which must run after the activity is attached.
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

    // Exact alarms may be unavailable (Android 12+ permission). Remember this
    // so scheduling can fall back to inexact alarms instead of failing.
    try {
      _canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _canScheduleExact = false;
    }

    try {
      _defaultAlarmUri = await AlarmSoundService.defaultAlarmUri();
    } catch (_) {
      _defaultAlarmUri = null;
    }
  }

  /// Captures the notification launch details on cold start. Must run after the
  /// activity is attached, otherwise the plugin returns no launch details.
  static Future<void> captureLaunchDetails() async {
    await init();
    try {
      _launchDetails = await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Verifi: launch-details lookup failed — $e');
    }
  }

  /// Whether the app was launched by an alarm notification (cold start).
  static bool get hasInitialPayload =>
      _launchDetails?.notificationResponse?.payload != null;

  /// Requests the runtime permissions alarms need (notifications and a
  /// full-screen intent so the alarm opens over the lock screen). Runs once per
  /// process; call only after the activity is attached.
  static Future<void> requestPermissions() async {
    await init();
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Verifi: notification permission request failed — $e');
    }
    try {
      await android?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('Verifi: full-screen-intent permission request failed — $e');
    }
    try {
      _canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {}
  }

  /// Whether the OS currently allows full-screen intents (Android 14+).
  static Future<bool> canUseFullScreenIntent() =>
      AlarmSoundService.canUseFullScreenIntent();

  /// Opens the Android "full screen intents" permission page when needed, then
  /// reports whether full-screen alarms are now allowed.
  static Future<bool> requestFullScreenIntentPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('Verifi: full-screen-intent permission request failed — $e');
    }
    return canUseFullScreenIntent();
  }

  /// Opens the Android "Alarms & reminders" settings so the user can grant the
  /// exact-alarm permission, then refreshes [canScheduleExact].
  static Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    try {
      _canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {}
    return _canScheduleExact;
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
        await _zonedSchedule(
          id: id++,
          title: m.name,
          body: m.dosageLine,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          payload: jsonEncode({'medicationId': m.id, 'time': clock12(at)}),
        );
      }
    }
  }

  /// Schedules a one-off "snoozed" reminder [minutes] from now.
  static Future<void> snooze(Medication m, String time, int minutes) async {
    await init();
    final at = DateTime.now().add(Duration(minutes: minutes));
    await _zonedSchedule(
      id: _snoozeId(m.id),
      title: m.name,
      body: m.dosageLine,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      payload: jsonEncode({'medicationId': m.id, 'time': time}),
    );
  }

  /// Schedules one notification, falling back to inexact if the exact-alarm
  /// permission was revoked after [init] ran.
  static Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _details(),
        androidScheduleMode: _scheduleMode(),
        payload: payload,
      );
    } catch (_) {
      if (!_canScheduleExact) rethrow;
      _canScheduleExact = false;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  /// Cancels the one-off snooze reminder for a medication, if any.
  static Future<void> cancelSnooze(String medicationId) async {
    await init();
    await _plugin.cancel(id: _snoozeId(medicationId));
  }

  /// Recreates the notification channel so a newly chosen alarm sound takes
  /// effect (on Android 8+ a channel's sound is fixed once created).
  static Future<void> applyAlarmSound(String? uri) async {
    await init();
    setAlarmSoundUri(uri);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.deleteNotificationChannel(channelId: _channelId);
    } catch (e) {
      debugPrint('Verifi: channel recreation failed — $e');
    }
  }

  static int _snoozeId(String medicationId) {
    // Keep within the int32 notification-id range; distinct from dose ids.
    return 100000 + medicationId.hashCode.abs() % 100000;
  }

  static AndroidScheduleMode _scheduleMode() => _canScheduleExact
      ? AndroidScheduleMode.alarmClock
      : AndroidScheduleMode.inexactAllowWhileIdle;

  static NotificationDetails _details() {
    // Prefer the user's chosen sound, then the device default alarm, then the
    // bundled raw resource as a final fallback.
    final uri = _alarmSoundUri ?? _defaultAlarmUri;
    final AndroidNotificationSound sound = (uri != null && uri.isNotEmpty)
        ? UriAndroidNotificationSound(uri)
        : const RawResourceAndroidNotificationSound('alarm');

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
        sound: sound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 400, 600]),
        autoCancel: false,
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
