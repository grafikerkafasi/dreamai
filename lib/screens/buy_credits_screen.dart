import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_routes.dart';
import '../openai_service.dart';
import '../services/purchase_service.dart';
import 'info_screen.dart';

const _privacyPolicyUrl = 'https://sanai.uk/dreamai/privacy-policy.html';

/// Lets a user top up with a one-time credit pack, independent of whether
/// their free/monthly quota is exhausted — a subscriber who just burns
/// through their 50 fast has no other way to keep going until next month
/// without this.
class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  Offering? _offering;
  bool _loadingOffering = true;
  String? _purchasingPackageId;
  String? _error;
  UsageInfo? _usage;

  @override
  void initState() {
    super.initState();
    _loadOffering();
    _loadUsage();
  }

  Future<void> _loadOffering() async {
    try {
      final offering = await PurchaseService.getCreditsOffering();
      if (!mounted) return;
      setState(() {
        _offering = offering;
        _loadingOffering = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOffering = false;
        _error = 'Unable to load credit packs. Please try again.';
      });
    }
  }

  Future<void> _loadUsage() async {
    final usage = await OpenAIService.getUsage();
    if (mounted) setState(() => _usage = usage);
  }

  Future<void> _buy(Package package) async {
    setState(() {
      _purchasingPackageId = package.identifier;
      _error = null;
    });

    final outcome = await PurchaseService.purchaseConsumable(package);
    // The backend applies credits via the RevenueCat webhook, but that can
    // lag or (if the webhook was never configured) never arrive — ask it
    // to double-check directly so the balance updates right away.
    final usage = await OpenAIService.redeemCredits();
    if (!mounted) return;

    setState(() {
      _purchasingPackageId = null;
      if (usage != null) _usage = usage;
    });

    switch (outcome) {
      case SubscribeOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credits added — enjoy!')),
        );
        break;
      case SubscribeOutcome.cancelled:
        break;
      case SubscribeOutcome.notEntitled:
      case SubscribeOutcome.failure:
        setState(() =>
            _error = 'Purchase could not be completed. Please try again.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show cheapest-to-priciest regardless of how they're ordered in the
    // RevenueCat dashboard, so pack size and price always line up visually.
    final packages = [...?_offering?.availablePackages]
      ..sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));

    return DreamPageScaffold(
      title: 'Get More Dreams',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        children: [
          Text('Get More Dreams', style: DreamPageStyles.heading),
          const SizedBox(height: 12),
          Text(
            'Running low? Top up with a one-time credit pack — no subscription needed, and they never expire.',
            style: DreamPageStyles.body,
          ),
          if (_usage != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_usage!.remaining} dream interpretations available',
              style: DreamPageStyles.subheading,
            ),
          ],
          const SizedBox(height: 28),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
          ],
          if (_loadingOffering)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (packages.isEmpty)
            Text(
              'Credit packs aren\'t available right now. Please check back later.',
              style: DreamPageStyles.body,
            )
          else
            for (final package in packages) ...[
              _CreditPackTile(
                package: package,
                purchasing: _purchasingPackageId == package.identifier,
                onTap:
                    _purchasingPackageId == null ? () => _buy(package) : null,
              ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.terms),
                child: Text(
                  'Terms of Use',
                  style: GoogleFonts.kufam(
                    fontSize: 12,
                    color: Colors.white54,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text('  •  ',
                  style:
                      GoogleFonts.kufam(fontSize: 12, color: Colors.white38)),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Privacy Policy',
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
    );
  }
}

class _CreditPackTile extends StatelessWidget {
  const _CreditPackTile({
    required this.package,
    required this.purchasing,
    required this.onTap,
  });

  final Package package;
  final bool purchasing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return Material(
      color: const Color(0x5139415C),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title.isNotEmpty
                          ? product.title
                          : product.identifier,
                      style: GoogleFonts.kufam(
                        color: const Color(0xFFFAEAD6),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: GoogleFonts.kufam(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              purchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      product.priceString,
                      style: GoogleFonts.kufam(
                        color: const Color(0xFFFF91B3),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
