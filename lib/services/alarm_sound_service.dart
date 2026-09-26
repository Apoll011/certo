import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the native Android alarm APIs (see `MainActivity.kt` and `AlarmBroadcastReceiver.kt`).
///
/// Lets the app:
/// 1. Schedule exact clock alarms with `AlarmManager.setAlarmClock`.
/// 2. Launch full-screen alarm intents waking the screen over the keyguard.
/// 3. Open system sound picker and play looping audio on the alarm stream.
/// 4. Dismiss alarm notifications when taken or snoozed.
class AlarmSoundService {
  AlarmSoundService._();

  static const MethodChannel _channel = MethodChannel(
    'com.skyhack.medication_reminder/alarm_sounds',
  );

  static void Function(String medicationId, String? time)? _alarmFiredHandler;
  static bool _handlerInstalled = false;

  static void setAlarmFiredHandler(
    void Function(String medicationId, String? time) handler,
  ) {
    _alarmFiredHandler = handler;
    _ensureHandler();
  }

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmFired') {
        final map = call.arguments as Map<dynamic, dynamic>?;
        if (map != null) {
          final medId = map['medicationId'] as String?;
          final time = map['time'] as String?;
          if (medId != null && medId.isNotEmpty) {
            _alarmFiredHandler?.call(medId, time);
          }
        }
      }
      return null;
    });
  }

  /// Retrieves any alarm that launched the app on cold start.
  static Future<({String medicationId, String? time})?> getPendingAlarm() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getPendingAlarm');
      if (map == null) return null;
      final medId = map['medicationId'] as String?;
      if (medId == null || medId.isEmpty) return null;
      return (medicationId: medId, time: map['time'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Schedules a native exact clock alarm that fires full-screen over the lock screen.
  static Future<void> scheduleNativeAlarm({
    required int id,
    required String title,
    required String body,
    required String medicationId,
    required String? time,
    required int timestampMs,
  }) async {
    try {
      await _channel.invokeMethod('scheduleNativeAlarm', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'medicationId': medicationId,
        'time': time,
        'timestamp': timestampMs,
      });
    } catch (e) {
      debugPrint('Verifi: scheduleNativeAlarm failed — $e');
    }
  }

  /// Cancels a native scheduled alarm by id.
  static Future<void> cancelNativeAlarm(int id) async {
    try {
      await _channel.invokeMethod('cancelNativeAlarm', <String, dynamic>{'id': id});
    } catch (_) {}
  }

  /// Dismisses an active notification from the system tray.
  static Future<void> dismissAlarmNotification([int? id]) async {
    try {
      await _channel.invokeMethod('dismissAlarmNotification', <String, dynamic>{
        'id': ?id,
      });
    } catch (_) {}
  }

  /// Whether the app can draw overlays ("Appear on top").
  static Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Appear on top" settings page.
  static Future<bool> openOverlaySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openOverlaySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The device's default alarm ringtone URI, or null if unavailable.
  static Future<String?> defaultAlarmUri() async {
    try {
      return await _channel.invokeMethod<String>('getDefaultAlarmUri');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable title for an alarm-sound URI (e.g. "Hassium").
  static Future<String?> titleFor(String? uri) async {
    if (uri == null || uri.isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>(
        'getAlarmSoundTitle',
        <String, dynamic>{'uri': uri},
      );
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Opens the native Android alarm-sound picker and returns the chosen URI,
  /// or null if the user cancelled.
  static Future<String?> pick() async {
    try {
      return await _channel.invokeMethod<String>('pickAlarmSound');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Plays [uri] in a loop on the alarm stream; a null [uri] plays the device
  /// default alarm sound.
  static Future<void> play(String? uri) async {
    try {
      await _channel.invokeMethod(
        'playAlarmSound',
        <String, dynamic>{'uri': uri},
      );
    } catch (_) {
      // Ignore: playback is best-effort and the notification still alerts.
    }
  }

  /// Stops the looping alarm sound.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (_) {}
  }

  /// Whether the OS currently allows full-screen intents (Android 14+). On
  /// other platforms/versions this is treated as allowed.
  static Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } on PlatformException {
      return true;
    } catch (_) {
      return true;
    }
  }
}
