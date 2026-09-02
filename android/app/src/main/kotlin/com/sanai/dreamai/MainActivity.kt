package com.sanai.dreamai

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val deviceIdChannel = "com.sanai.dreamai/device_id"
    private val instagramStoryChannel = "com.sanai.dreamai/instagram_story"
    private val instagramPackage = "com.instagram.android"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ANDROID_ID is stable across an uninstall/reinstall of this app (it's
        // scoped to app-signing-key + user + device, not to the install itself),
        // so DeviceIdService can use it to recover a returning user's identity
        // without any login. See device_id_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceIdChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
                } else {
                    result.notImplemented()
                }
            }

        // Shares an already-rendered PNG straight into the Instagram Stories
        // composer via the ADD_TO_STORY intent, instead of the generic OS
        // share sheet. See instagram_story_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, instagramStoryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstagramAvailable" -> result.success(isInstagramInstalled())
                    "shareToStory" -> {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath == null) {
                            result.success(false)
                        } else {
                            result.success(shareToInstagramStory(imagePath))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInstagramInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(instagramPackage, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun shareToInstagramStory(imagePath: String): Boolean {
        return try {
            val file = File(imagePath)
            if (!file.exists()) return false

            val uri: Uri = FileProvider.getUriForFile(
                this, "$packageName.storyprovider", file
            )

            val intent = Intent("com.instagram.share.ADD_TO_STORY")
            intent.setDataAndType(uri, "image/png")
            intent.putExtra("source_application", packageName)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.setPackage(instagramPackage)
            grantUriPermission(instagramPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
