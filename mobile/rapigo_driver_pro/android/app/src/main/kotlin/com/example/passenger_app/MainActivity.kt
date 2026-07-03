package com.rapigo.driver

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updaterChannel = "rapigo.updater"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        val authority = call.argument<String>("authority")
                        if (filePath.isNullOrBlank() || authority.isNullOrBlank()) {
                            result.error("invalid_args", "filePath/authority requeridos", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(filePath, authority)
                            result.success(null)
                        } catch (error: Throwable) {
                            result.error("install_failed", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(filePath: String, authority: String) {
        val apkFile = File(filePath)
        val apkUri = FileProvider.getUriForFile(this, authority, apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
