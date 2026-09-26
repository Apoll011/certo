import 'package:flutter/services.dart';

/// Bridge to the native Android alarm-sound APIs (see `MainActivity.kt`).
///
/// Lets the app open the system alarm-sound picker, resolve the default alarm
/// ringtone, and play a selected sound in a loop on the alarm audio stream —
/// the same stream a stock clock alarm uses, so it rings even when the device
/// is in silent/vibrate mode.
class AlarmSoundService {
  AlarmSoundService._();

  static const MethodChannel _channel = MethodChannel(
    'com.skyhack.medication_reminder/alarm_sounds',
  );

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
