package com.sanai.dreamai

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceIdChannel = "com.sanai.dreamai/device_id"

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
    }
}
