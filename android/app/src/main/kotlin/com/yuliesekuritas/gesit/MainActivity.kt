package com.yuliesekuritas.gesit

import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var foregroundAlertPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureGooglePlayServicesAvailable()
    }

    override fun onResume() {
        super.onResume()
        ensureGooglePlayServicesAvailable()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gesit/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                "openUnknownAppSourcesSettings" -> {
                    openUnknownAppSourcesSettings()
                    result.success(null)
                }

                "installApk" -> handleInstallApk(call, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gesit/notification_audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playForegroundAlert" -> playForegroundAlert(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        foregroundAlertPlayer?.release()
        foregroundAlertPlayer = null
        super.onDestroy()
    }

    private fun canRequestPackageInstalls(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }

        return packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppSourcesSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }

    private fun handleInstallApk(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")?.trim()
        if (filePath.isNullOrEmpty()) {
            result.error("invalid_args", "APK file path is required.", null)
            return
        }

        val apkFile = File(filePath)
        if (!apkFile.exists()) {
            result.error("missing_file", "APK file was not found.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            apkFile,
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val resolveInfo = packageManager.resolveActivity(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        if (resolveInfo == null) {
            result.error(
                "installer_unavailable",
                "No Android installer is available for this APK.",
                null,
            )
            return
        }

        startActivity(intent)
        result.success(null)
    }

    private fun playForegroundAlert(result: MethodChannel.Result) {
        try {
            foregroundAlertPlayer?.release()
            foregroundAlertPlayer = null

            val soundUri = Uri.parse(
                "android.resource://$packageName/${R.raw.yulie_sekuritas_notifikasi_v2}",
            )
            val player = MediaPlayer()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build(),
                )
            }

            player.setDataSource(this, soundUri)
            player.setOnCompletionListener { completedPlayer ->
                completedPlayer.release()
                if (foregroundAlertPlayer == completedPlayer) {
                    foregroundAlertPlayer = null
                }
            }
            player.setOnErrorListener { errorPlayer, _, _ ->
                errorPlayer.release()
                if (foregroundAlertPlayer == errorPlayer) {
                    foregroundAlertPlayer = null
                }
                true
            }
            player.prepare()
            foregroundAlertPlayer = player
            player.start()
            result.success(null)
        } catch (error: Exception) {
            foregroundAlertPlayer?.release()
            foregroundAlertPlayer = null
            result.error(
                "foreground_sound_failed",
                error.localizedMessage ?: "Unable to play notification sound.",
                null,
            )
        }
    }

    private fun ensureGooglePlayServicesAvailable() {
        val availability = GoogleApiAvailability.getInstance()
        val status = availability.isGooglePlayServicesAvailable(this)
        if (status == ConnectionResult.SUCCESS) {
            return
        }

        if (availability.isUserResolvableError(status)) {
            availability.makeGooglePlayServicesAvailable(this)
        }
    }
}
