package com.yuliesekuritas.gesit

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process

class GesitCallNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        if (!isCallPayload(extras)) {
            return
        }
        if (isAppInForeground(context)) {
            return
        }

        ensureCallChannel(context)
        showIncomingCallNotification(context, extras)
    }

    private fun isCallPayload(extras: Bundle): Boolean {
        val category = extras.stringValue("notification_category") ?: extras.stringValue("category")
        val type = extras.stringValue("type")
        val link = extras.stringValue("link") ?: ""

        return category == "call" || type == "chat_call" || link.contains("call=")
    }

    private fun showIncomingCallNotification(context: Context, extras: Bundle) {
        val title = extras.stringValue("title") ?: "Panggilan GESIT"
        val body = extras.stringValue("message") ?: "Panggilan masuk"
        val callId = extras.stringValue("call_id") ?: extras.stringValue("notification_id") ?: title
        val conversationId = extras.stringValue("conversation_id")
        val link = extras.stringValue("link") ?: buildChatCallLink(conversationId, callId, null)
        val notificationId = stableNotificationId(callId)

        val openIntent = pendingIntentFor(context, link, notificationId, null)
        val answerIntent = pendingIntentFor(context, link, notificationId + 1, "answer")
        val declineIntent = pendingIntentFor(context, link, notificationId + 2, "decline")

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CALL_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openIntent)
            .setFullScreenIntent(openIntent, true)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.sym_call_missed,
                    "Tolak",
                    declineIntent,
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.sym_call_incoming,
                    "Terima",
                    answerIntent,
                ).build(),
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setTimeoutAfter(CALL_TIMEOUT_MS)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val caller = Person.Builder()
                .setName(title)
                .setImportant(true)
                .build()
            builder.setStyle(
                Notification.CallStyle.forIncomingCall(
                    caller,
                    declineIntent,
                    answerIntent,
                ),
            )
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_MAX)
            @Suppress("DEPRECATION")
            builder.setDefaults(Notification.DEFAULT_VIBRATE)
            builder.setSound(callSoundUri(context))
        }

        context.getSystemService(NotificationManager::class.java)
            .notify(notificationId, builder.build())
    }

    private fun pendingIntentFor(
        context: Context,
        rawLink: String,
        requestCode: Int,
        action: String?,
    ): PendingIntent {
        val deepLink = appendActionToLink(rawLink, action)
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            this.action = Intent.ACTION_VIEW
            data = Uri.parse(deepLink)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        return PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun appendActionToLink(rawLink: String, action: String?): String {
        val normalized = rawLink.ifBlank { "gesit://app/chat" }
        val uri = Uri.parse(
            if (normalized.startsWith("/") || normalized.startsWith("chat/")) {
                "gesit://app$normalized"
            } else {
                normalized
            },
        )
        if (action == null) {
            return uri.toString()
        }

        return uri.buildUpon()
            .appendQueryParameter("notification_action", action)
            .build()
            .toString()
    }

    private fun buildChatCallLink(
        conversationId: String?,
        callId: String,
        action: String?,
    ): String {
        val base = if (conversationId.isNullOrBlank()) {
            "gesit://app/chat"
        } else {
            "gesit://app/chat/conversations/$conversationId"
        }
        val builder = Uri.parse(base).buildUpon()
            .appendQueryParameter("call", callId)
        if (!action.isNullOrBlank()) {
            builder.appendQueryParameter("notification_action", action)
        }
        return builder.build().toString()
    }

    private fun isAppInForeground(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val processes = manager.runningAppProcesses ?: return false
        val myPid = Process.myPid()
        return processes.any { process ->
            process.pid == myPid &&
                process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }

    private fun ensureCallChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            CALL_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CALL_CHANNEL_DESCRIPTION
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(
                callSoundUri(context),
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .build(),
            )
        }

        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun callSoundUri(context: Context): Uri {
        return Uri.parse("android.resource://${context.packageName}/${R.raw.yulie_sekuritas_notifikasi_v2}")
    }

    private fun stableNotificationId(seed: String): Int {
        var hash = 17
        seed.forEach { char -> hash = (hash * 31) + char.code }
        return hash and 0x7fffffff
    }

    private fun Bundle.stringValue(key: String): String? {
        val raw = get(key) ?: return null
        return raw.toString().trim().takeIf { it.isNotEmpty() && it != "null" }
    }

    companion object {
        private const val CALL_CHANNEL_ID = "gesit.calls.incoming.v5"
        private const val CALL_CHANNEL_NAME = "GESIT Calls"
        private const val CALL_CHANNEL_DESCRIPTION =
            "Panggilan suara dan video masuk GESIT."
        private const val CALL_TIMEOUT_MS = 25_000L
    }
}
