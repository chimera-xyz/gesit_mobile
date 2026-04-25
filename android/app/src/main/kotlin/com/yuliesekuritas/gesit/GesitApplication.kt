package com.yuliesekuritas.gesit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import io.flutter.app.FlutterApplication

class GesitApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val soundUri = Uri.parse("android.resource://$packageName/${R.raw.yulie_sekuritas_notifikasi_v2}")
        val notificationAudioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()
        val ringtoneAudioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .build()

        val generalChannel = NotificationChannel(
            GENERAL_CHANNEL_ID,
            GENERAL_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = GENERAL_CHANNEL_DESCRIPTION
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(soundUri, notificationAudioAttributes)
        }

        val callChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            CALL_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CALL_CHANNEL_DESCRIPTION
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(soundUri, ringtoneAudioAttributes)
        }

        getSystemService(NotificationManager::class.java).createNotificationChannels(
            listOf(generalChannel, callChannel),
        )
    }

    companion object {
        private const val GENERAL_CHANNEL_ID = "gesit.general.high_priority.v4"
        private const val GENERAL_CHANNEL_NAME = "GESIT Alerts"
        private const val GENERAL_CHANNEL_DESCRIPTION =
            "Notifikasi prioritas tinggi untuk aktivitas GESIT."

        private const val CALL_CHANNEL_ID = "gesit.calls.incoming.v4"
        private const val CALL_CHANNEL_NAME = "GESIT Calls"
        private const val CALL_CHANNEL_DESCRIPTION =
            "Notifikasi panggilan masuk GESIT dengan tampilan penuh."
    }
}
