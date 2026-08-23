import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'device_id_service.dart';

/// Thin wrapper around the RevenueCat SDK. RevenueCat owns the App
/// Store / Play Billing purchase flow and receipt validation; this app
/// only asks it "is this device entitled" and "let the user buy the
/// subscription". The backend's usage_store.js is the source of truth
/// for quota, kept in sync via RevenueCat's webhook.
class PurchaseService {
  // Must match the entitlement's exact "Identifier" in the RevenueCat
  // dashboard (Product catalog > Entitlements) — not its display name.
  static const entitlementId = 'DreamAI Premium';

  // The RevenueCat *offering* identifier that holds the one-time
  // credit-pack products (distinct from the "default" subscription
  // offering) — must match what's created in the dashboard.
  static const creditsOfferingId = 'credits';

  static const _iosApiKey = String.fromEnvironment('REVENUECAT_API_KEY_IOS');
  static const _androidApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');

  static bool _configured = false;

  static Future<void> configure() async {
    if (_configured) return;
    // purchases_flutter wraps StoreKit/Play Billing; there is no web
    // storefront, so leave the SDK unconfigured there rather than
    // touching dart:io's Platform, which throws on the web target.
    if (kIsWeb) return;
    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    if (apiKey.isEmpty) {
      // No RevenueCat key supplied at build time (e.g. local/demo builds).
      // Leave the SDK unconfigured; callers should treat purchases as
      // unavailable rather than crash.
      return;
    }
    final deviceId = await DeviceIdService.getId();
    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = deviceId,
    );
    _configured = true;
  }

  static bool get isAvailable => _configured;

  static Future<Offering?> getMonthlyOffering() async {
    if (!_configured) return null;
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  }

  /// The offering holding one-time credit-pack products, or null if it
  /// doesn't exist yet (e.g. not configured in RevenueCat) or the SDK
  /// isn't configured.
  static Future<Offering?> getCreditsOffering() async {
    if (!_configured) return null;
    final offerings = await Purchases.getOfferings();
    return offerings.all[creditsOfferingId];
  }

  static Future<SubscribeOutcome> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final active =
          result.customerInfo.entitlements.active.containsKey(entitlementId);
      return active ? SubscribeOutcome.success : SubscribeOutcome.notEntitled;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return SubscribeOutcome.cancelled;
      }
      return SubscribeOutcome.failure;
    } catch (_) {
      // Anything the SDK throws that isn't a PlatformException still has to
      // become an outcome, or the caller's loading indicator hangs forever.
      return SubscribeOutcome.failure;
    }
  }

  /// Buys a one-time credit pack. Unlike [purchase], there's no entitlement
  /// to check afterwards — success just means the store confirmed the
  /// purchase; the backend applies the actual credits (via webhook, or the
  /// caller should follow up with OpenAIService.redeemCredits()).
  static Future<SubscribeOutcome> purchaseConsumable(Package package) async {
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return SubscribeOutcome.success;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return SubscribeOutcome.cancelled;
      }
      return SubscribeOutcome.failure;
    } catch (_) {
      return SubscribeOutcome.failure;
    }
  }

  static Future<bool> restore() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      // Same reason as above: report "nothing restored" rather than letting
      // the exception escape and strand the caller's spinner.
      return false;
    }
  }
}

enum SubscribeOutcome { success, cancelled, notEntitled, failure }
