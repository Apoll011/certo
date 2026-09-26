package com.skyhack.medication_reminder

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the alarm-sound bridge used by the alarm screen and notification.
 *
 * It lets the Dart side open the native Android alarm-sound picker, resolve the
 * title/URI of the device's default alarm sound, and play any selected ringtone
 * in a loop on the alarm audio stream (so it rings even in silent/vibrate mode,
 * exactly like a stock clock alarm).
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.skyhack.medication_reminder/alarm_sounds"
        private const val PICK_ALARM_REQUEST = 4001
    }

    private var mediaPlayer: MediaPlayer? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                    else -> result.notImplemented()
                }
            }
    }

    // -------------------------------------------------------------------------
    // Alarm sound helpers
    // -------------------------------------------------------------------------

    private fun defaultAlarmUri(): Uri? =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

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
        // Important: forward to Flutter so the local-notifications plugin still
        // receives its own permission-request results.
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
                // Last-resort fallback to the bundled alarm.wav.
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

    override fun onDestroy() {
        stopAlarmSound()
        super.onDestroy()
    }
}
