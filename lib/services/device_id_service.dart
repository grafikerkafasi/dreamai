import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install identifier used both as the backend's quota key
/// and as RevenueCat's app_user_id, so the two systems agree on who a
/// "user" is without requiring an account or login.
///
/// Plain SharedPreferences is wiped on uninstall, which would silently
/// disconnect a returning user from their existing credits/subscription
/// the moment they delete and reinstall the app. Two device-level (not
/// account-level) tricks recover the same id across a reinstall on the
/// *same* device, without any login:
///  - iOS: the id is mirrored into the Keychain, which — unlike
///    SharedPreferences — isn't cleared when the app is deleted.
///  - Android: `Settings.Secure.ANDROID_ID` is stable for a given
///    (signing key, user, device) combination across reinstalls, so a
///    fresh install with no SharedPreferences value falls back to it
///    instead of minting a brand-new random id.
/// Neither trick survives moving to a different device or a factory
/// reset — that would need real login.
class DeviceIdService {
  static const _key = 'device_id';
  static const _androidIdChannel =
      MethodChannel('com.sanai.dreamai/device_id');
  static const _secureStorage = FlutterSecureStorage();
  static String? _cached;

  static Future<String> getId() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);

    if (id == null) {
      // No local id: either a genuine first launch, or a reinstall that
      // wiped SharedPreferences. Try to recover a stable device-level id
      // before minting a fresh one.
      id = await _recoverDeviceLevelId();
      id ??= const Uuid().v4();
      await prefs.setString(_key, id);
    }

    // Keep the Keychain copy in sync so a *future* reinstall can recover
    // this id too — including for installs that already had an id before
    // this logic shipped.
    if (!kIsWeb && Platform.isIOS) {
      await _secureStorage.write(key: _key, value: id);
    }

    _cached = id;
    return id;
  }

  static Future<String?> _recoverDeviceLevelId() async {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      return _secureStorage.read(key: _key);
    }
    if (Platform.isAndroid) {
      try {
        final androidId =
            await _androidIdChannel.invokeMethod<String>('getAndroidId');
        return (androidId == null || androidId.isEmpty) ? null : androidId;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
