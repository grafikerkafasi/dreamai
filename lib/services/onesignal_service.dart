import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Callback invoked with the device's current OneSignal push subscription
/// ID whenever it changes (and once immediately on registration). `null`
/// or an empty/`local-`-prefixed ID means the device has not yet finished
/// registering with OneSignal's servers.
typedef PushSubscriptionIdListener = void Function(String? subscriptionId);

/// Thin wrapper around the OneSignal SDK. Every direct
/// `package:onesignal_flutter` call lives here so the rest of the app never
/// imports the SDK itself — mirrors the existing `PurchaseService` pattern
/// for RevenueCat.
class OneSignalService {
  static const _appId = '0f45eed0-1f24-49a3-ac90-96e29ccc7618';

  static bool _initialized = false;

  // onesignal_flutter only supports Android and iOS; skip everywhere else
  // (web, desktop) rather than let the SDK throw on an unsupported target.
  static bool get _supportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static void initialize() {
    if (_initialized || !_supportedPlatform) return;
    // TODO: lower to a less verbose level (or remove) once the integration
    // is verified end to end on real devices.
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_appId);
    _initialized = true;
  }

  static void login(String externalId) {
    if (!_initialized) return;
    OneSignal.login(externalId);
  }

  static void logout() {
    if (!_initialized) return;
    OneSignal.logout();
  }

  static void addEmail(String email) {
    if (!_initialized) return;
    OneSignal.User.addEmail(email);
  }

  static void addSms(String number) {
    if (!_initialized) return;
    OneSignal.User.addSms(number);
  }

  static void setTag(String key, String value) {
    if (!_initialized) return;
    OneSignal.User.addTagWithKey(key, value);
  }

  static void setLogLevel(OSLogLevel level) {
    if (!_initialized) return;
    OneSignal.Debug.setLogLevel(level);
  }

  static Future<bool> requestPermission() async {
    if (!_initialized) return false;
    return OneSignal.Notifications.requestPermission(true);
  }

  /// The device's current push subscription ID, if OneSignal has already
  /// assigned one (see `PushSubscriptionIdListener` for what counts as a
  /// real, server-assigned ID).
  static String? get currentPushSubscriptionId =>
      _initialized ? OneSignal.User.pushSubscription.id : null;

  /// Registers [listener] to be called whenever the push subscription ID
  /// changes. Does not fire immediately with the current value — callers
  /// should also check [currentPushSubscriptionId] right after calling
  /// this, since the ID may already be assigned before the listener
  /// attaches.
  static void addPushSubscriptionIdListener(
    PushSubscriptionIdListener listener,
  ) {
    if (!_initialized) return;
    OneSignal.User.pushSubscription.addObserver((state) {
      listener(state.current.id);
    });
  }
}
