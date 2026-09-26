package com.skyhack.medication_reminder

import android.app.ActivityOptions
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Fires when an AlarmManager clock alarm triggers.
 *
 * It wakes the device (turning the screen on), builds a high-priority
 * notification with a full-screen intent configured with Android 14+ background
 * activity launch privileges, and attempts a direct startActivity launch to
 * bring the alarm screen up immediately without requiring user interaction.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "medication_alarms"
        const val CHANNEL_NAME = "Medication alarms"
        private const val TAG = "AlarmReceiver"
        const val ACTION_ALARM_TRIGGER = "com.skyhack.medication_reminder.ALARM_TRIGGER"
        const val ACTION_ALARM_FIRED = "com.skyhack.medication_reminder.ALARM_FIRED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 1001)
        val title = intent.getStringExtra("title") ?: "Medication Reminder"
        val body = intent.getStringExtra("body") ?: "Time for your dose"
        val medicationId = intent.getStringExtra("medicationId") ?: ""
        val time = intent.getStringExtra("time")

        Log.d(TAG, "Alarm triggered: id=$id, medId=$medicationId, time=$time")

        // 1. Acquire WakeLock to turn on and keep screen on.
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        @Suppress("DEPRECATION")
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "verifi:alarm_wake_lock"
        )
        wakeLock?.acquire(15000L) // 15 seconds

        // 2. Ensure notification channel exists with high importance & alarm audio stream.
        createNotificationChannel(context)

        // 3. Build launch Intent for MainActivity.
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_ALARM_FIRED
            putExtra("medicationId", medicationId)
            putExtra("time", time)
            putExtra("title", title)
            putExtra("notificationId", id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }

        // Android 14+ background activity launch options
        val activityOptions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ActivityOptions.makeBasic()
                .setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                )
                .toBundle()
        } else {
            null
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val fullScreenPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && activityOptions != null) {
            PendingIntent.getActivity(context, id, launchIntent, pendingFlags, activityOptions)
        } else {
            PendingIntent.getActivity(context, id, launchIntent, pendingFlags)
        }

        // 4. Try direct startActivity (succeeds when unlocked, with overlay permission, or when allowed)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && activityOptions != null) {
                context.startActivity(launchIntent, activityOptions)
            } else {
                context.startActivity(launchIntent)
            }
            Log.d(TAG, "Direct startActivity succeeded")
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity blocked or failed: ${e.message}; full-screen intent will take over")
        }

        // 5. Post the notification with fullScreenIntent so OS launches activity or displays heads-up
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .setSound(defaultSoundUri)
            .setVibrate(longArrayOf(0, 600, 400, 600))
            .setColor(0xFF2277EE.toInt())

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(id, notificationBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post alarm notification: ${e.message}")
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return

            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when it is time to take a medication"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 400, 600)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                setSound(soundUri, audioAttributes)
            }

            notificationManager.createNotificationChannel(channel)
        }
    }
}
