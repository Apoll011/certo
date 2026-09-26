package com.skyhack.medication_reminder

import android.app.Activity
import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main application activity.
 *
 * Configures the window to turn the screen on and show on top of the lock screen
 * when launched by an alarm. Bridges native Android alarm clock APIs and
 * alarm ringtones to Flutter.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.skyhack.medication_reminder/alarm_sounds"
        private const val PICK_ALARM_REQUEST = 4001
        private const val TAG = "MainActivity"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var pendingAlarm: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        turnScreenOnAndKeyguard()
        handleAlarmIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        turnScreenOnAndKeyguard()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        turnScreenOnAndKeyguard()
        handleAlarmIntent(intent)
    }

    private fun turnScreenOnAndKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        }
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent == null) return
        val medId = intent.getStringExtra("medicationId")
        if (medId.isNullOrEmpty()) return

        val time = intent.getStringExtra("time")
        val data = mapOf("medicationId" to medId, "time" to time)
        Log.d(TAG, "Alarm intent received: $data")

        val channel = methodChannel
        if (channel != null) {
            channel.invokeMethod("onAlarmFired", data)
        } else {
            pendingAlarm = data
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAlarm" -> {
                    result.success(pendingAlarm)
                    pendingAlarm = null
                }
                "getDefaultAlarmUri" -> result.success(defaultAlarmUri()?.toString())
                "getAlarmSoundTitle" -> result.success(
                    alarmSoundTitle(call.argument("uri"))
                )
                "pickAlarmSound" -> {
                    pendingPickResult = result
                    openAlarmSoundPicker()
                }
                "playAlarmSound" -> {
                    playAlarmSound(call.argument("uri"))
                    result.success(null)
                }
                "stopAlarmSound" -> {
                    stopAlarmSound()
                    result.success(null)
                }
                "canUseFullScreenIntent" -> {
                    result.success(canUseFullScreenIntent())
                }
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "openOverlaySettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "scheduleNativeAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Medication Reminder"
                    val body = call.argument<String>("body") ?: "Time for your dose"
                    val medicationId = call.argument<String>("medicationId") ?: ""
                    val time = call.argument<String>("time")
                    val timestamp = call.argument<Long>("timestamp") ?: 0L
                    scheduleNativeAlarm(id, title, body, medicationId, time, timestamp)
                    result.success(true)
                }
                "cancelNativeAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelNativeAlarm(id)
                    result.success(true)
                }
                "cancelAllNativeAlarms" -> {
                    result.success(true)
                }
                "dismissAlarmNotification" -> {
                    val id = call.argument<Int>("id")
                    if (id != null) {
                        NotificationManagerCompat.from(this).cancel(id)
                    } else {
                        NotificationManagerCompat.from(this).cancelAll()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Deliver pending alarm if one was captured during onCreate before the engine was configured.
        if (pendingAlarm != null) {
            channel.invokeMethod("onAlarmFired", pendingAlarm)
        }
    }

    // -------------------------------------------------------------------------
    // Alarm sound helpers
    // -------------------------------------------------------------------------

    private fun defaultAlarmUri(): Uri? =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

    /** Whether the OS currently allows full-screen intents (Android 14+). */
    private fun canUseFullScreenIntent(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.canUseFullScreenIntent() ?: true
        } else {
            true
        }
    }

    private fun alarmSoundTitle(rawUri: String?): String? {
        if (rawUri.isNullOrEmpty()) return null
        val uri = runCatching { Uri.parse(rawUri) }.getOrNull() ?: return null
        val ringtone = runCatching { RingtoneManager.getRingtone(this, uri) }.getOrNull()
        return ringtone?.getTitle(this) ?: "Custom sound"
    }

    private fun openAlarmSoundPicker() {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose alarm sound")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, defaultAlarmUri())
        }
        startActivityForResult(intent, PICK_ALARM_REQUEST)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != PICK_ALARM_REQUEST) return
        val pending = pendingPickResult
        pendingPickResult = null
        if (pending == null) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            val uri = data.getParcelableExtra(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI
            ) as? Uri
            pending.success(uri?.toString())
        } else {
            pending.success(null)
        }
    }

    // -------------------------------------------------------------------------
    // Looping playback on the alarm stream
    // -------------------------------------------------------------------------

    private fun playAlarmSound(rawUri: String?) {
        stopAlarmSound()

        val uri = rawUri?.let { runCatching { Uri.parse(it) }.getOrNull() }
            ?: defaultAlarmUri()

        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )

            if (uri != null) {
                player.setDataSource(this, uri)
            } else {
                val afd = resources.openRawResourceFd(R.raw.alarm)
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            }

            player.isLooping = true
            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (e: Exception) {
            runCatching { player.release() }
        }
    }

    private fun stopAlarmSound() {
        runCatching { mediaPlayer?.stop() }
        runCatching { mediaPlayer?.release() }
        mediaPlayer = null
    }

    // -------------------------------------------------------------------------
    // Native AlarmClock scheduling
    // -------------------------------------------------------------------------

    private fun scheduleNativeAlarm(
        id: Int,
        title: String,
        body: String,
        medicationId: String,
        time: String?,
        epochMilli: Long
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(this, AlarmBroadcastReceiver::class.java).apply {
            action = AlarmBroadcastReceiver.ACTION_ALARM_TRIGGER
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("medicationId", medicationId)
            putExtra("time", time)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val operation = PendingIntent.getBroadcast(this, id, intent, flags)

        val showIntent = Intent(this, MainActivity::class.java).apply {
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val showOperation = PendingIntent.getActivity(this, id, showIntent, flags)

        val clockInfo = AlarmManager.AlarmClockInfo(epochMilli, showOperation)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAlarmClock(clockInfo, operation)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMilli, operation)
                }
            } else {
                alarmManager.setAlarmClock(clockInfo, operation)
            }
            Log.d(TAG, "Scheduled native alarm $id at $epochMilli for med $medicationId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule native alarm $id: ${e.message}")
        }
    }

    private fun cancelNativeAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(this, AlarmBroadcastReceiver::class.java).apply {
            action = AlarmBroadcastReceiver.ACTION_ALARM_TRIGGER
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val operation = PendingIntent.getBroadcast(this, id, intent, flags)
        alarmManager.cancel(operation)
    }

    override fun onDestroy() {
        stopAlarmSound()
        super.onDestroy()
    }
}
