import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_routes.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/purchase_service.dart';

const _privacyPolicyUrl = 'https://sanai.uk/dreamai/privacy-policy.html';

class PaywallScreen extends StatefulWidget {
  final String message;

  const PaywallScreen({super.key, required this.message});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offering? _offering;
  bool _loadingOffering = true;
  bool _purchasing = false;
  String? _error;

  Package? get _firstAvailablePackage {
    final packages = _offering?.availablePackages ?? const [];
    return packages.isEmpty ? null : packages.first;
  }

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    try {
      final offering = await PurchaseService.getMonthlyOffering();
      if (!mounted) return;
      setState(() {
        _offering = offering;
        _loadingOffering = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOffering = false;
        _error = AppLocalizations.of(context)!.subscriptionLoadError;
      });
    }
  }

  Future<void> _subscribe() async {
    final package = _offering?.monthly ?? _firstAvailablePackage;
    if (package == null) return;

    setState(() {
      _purchasing = true;
      _error = null;
    });

    // No timeout: the store sheet waits on the user (password, Face ID,
    // "Ask to Buy"), and a Dart-side timeout can't cancel the transaction —
    // it would only misreport a purchase that actually went through.
    // PurchaseService turns every error into an outcome instead.
    final outcome = await PurchaseService.purchase(package);
    if (!mounted) return;

    setState(() => _purchasing = false);

    switch (outcome) {
      case SubscribeOutcome.success:
        Navigator.pop(context, true);
        break;
      case SubscribeOutcome.cancelled:
        break;
      case SubscribeOutcome.notEntitled:
      case SubscribeOutcome.failure:
        setState(
            () => _error = AppLocalizations.of(context)!.purchaseFailedGeneric);
        break;
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final restored = await PurchaseService.restore();
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (restored) {
      Navigator.pop(context, true);
    } else {
      setState(
          () => _error = AppLocalizations.of(context)!.noActiveSubscription);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final package = _offering?.monthly ?? _firstAvailablePackage;
    final priceText = package?.storeProduct.priceString ?? '\$4.99/month';

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/homepage-bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFFF91B3),
              size: 30,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome,
                    color: const Color(0xFFFF91B3), size: 48),
                const SizedBox(height: 20),
                Text(
                  l10n.unlockMoreDreams,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kufam(
                    fontSize: 22,
                    color: const Color(0xFFFF91B3),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kufam(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.subscriptionOfferBody(priceText),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kufam(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_loadingOffering || _purchasing || package == null)
                            ? null
                            : _subscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xDFF0F8E9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _purchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _loadingOffering
                                ? l10n.loadingButton
                                : package == null
                                    ? l10n.notAvailableButton
                                    : l10n.subscribeButton,
                            style: GoogleFonts.kufam(
                              fontSize: 18,
                              color: const Color(0xFF81546F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _purchasing ? null : _restore,
                  child: Text(
                    l10n.restorePurchases,
                    style: GoogleFonts.kufam(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.reflectionDisclaimer,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kufam(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.terms),
                      child: Text(
                        l10n.termsOfUse,
                        style: GoogleFonts.kufam(
                          fontSize: 12,
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text('  •  ',
                        style: GoogleFonts.kufam(
                            fontSize: 12, color: Colors.white38)),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(_privacyPolicyUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        l10n.privacyPolicyLink,
                        style: GoogleFonts.kufam(
                          fontSize: 12,
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
