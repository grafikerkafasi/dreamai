import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_routes.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/who_should_interpret_screen.dart';
import 'screens/previous_dreams_screen.dart';
import 'screens/buy_credits_screen.dart';
import 'screens/custom_drawer.dart'; // ← Drawer'ı import et
import 'screens/app_logo_button.dart';
import 'screens/contact_screen.dart';
import 'screens/history_button.dart';
import 'screens/info_screen.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PurchaseService.configure();
  runApp(const DreamAIApp());
}

class DreamAIApp extends StatelessWidget {
  const DreamAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamAI',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.dream,
      routes: {
        AppRoutes.dream: (context) => const DreamPage(),
        AppRoutes.previousDreams: (context) => const PreviousDreamsScreen(),
        AppRoutes.buyCredits: (context) => const BuyCreditsScreen(),
        AppRoutes.contact: (context) => const ContactScreen(),
        AppRoutes.privacy: (context) {
          final l10n = AppLocalizations.of(context)!;
          return InfoScreen(
            title: l10n.privacyPolicyTitle,
            sections: [
              InfoSection(
                heading: l10n.privacySectionDreamContentHeading,
                body: l10n.privacySectionDreamContentBody,
              ),
              InfoSection(
                heading: l10n.privacySectionDeviceIdHeading,
                body: l10n.privacySectionDeviceIdBody,
              ),
              InfoSection(
                heading: l10n.privacySectionPurchasesHeading,
                body: l10n.privacySectionPurchasesBody,
              ),
              InfoSection(
                heading: l10n.privacySectionSupportHeading,
                body: l10n.privacySectionSupportBody,
              ),
              InfoSection(
                heading: l10n.privacySectionUsageHeading,
                body: l10n.privacySectionUsageBody,
              ),
              InfoSection(
                heading: l10n.privacySectionThirdPartyHeading,
                body: l10n.privacySectionThirdPartyBody,
              ),
              InfoSection(
                heading: l10n.privacySectionRetentionHeading,
                body: l10n.privacySectionRetentionBody,
              ),
              InfoSection(
                heading: l10n.privacySectionChoicesHeading,
                body: l10n.privacySectionChoicesBody,
              ),
              InfoSection(
                heading: l10n.privacySectionChildrenHeading,
                body: l10n.privacySectionChildrenBody,
              ),
              InfoSection(
                heading: l10n.privacySectionChangesHeading,
                body: l10n.privacySectionChangesBody,
              ),
              InfoSection(
                heading: l10n.privacySectionContactHeading,
                body: l10n.privacySectionContactBody,
              ),
            ],
          );
        },
        AppRoutes.terms: (context) {
          final l10n = AppLocalizations.of(context)!;
          return InfoScreen(
            title: l10n.termsTitle,
            sections: [
              InfoSection(
                heading: l10n.termsSectionReflectionHeading,
                body: l10n.termsSectionReflectionBody,
              ),
              InfoSection(
                heading: l10n.termsSectionCareHeading,
                body: l10n.termsSectionCareBody,
              ),
            ],
          );
        },
      },
    );
  }
}

class DreamPage extends StatefulWidget {
  const DreamPage({super.key});

  @override
  State<DreamPage> createState() => _DreamPageState();
}

class _DreamPageState extends State<DreamPage> {
  static const _typeDelay = Duration(milliseconds: 40);
  static const _holdDelay = Duration(milliseconds: 1400);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isFocused = false;
  String _hintText = '';
  bool _typewriterStarted = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_typewriterStarted) {
      _typewriterStarted = true;
      final l10n = AppLocalizations.of(context)!;
      _runPlaceholderTypewriter([
        l10n.dreamPlaceholder1,
        l10n.dreamPlaceholder2,
        l10n.dreamPlaceholder3,
        l10n.dreamPlaceholder4,
        l10n.dreamPlaceholder5,
      ]);
    }
  }

  Future<void> _runPlaceholderTypewriter(List<String> dreams) async {
    var index = 0;
    while (mounted) {
      final dream = dreams[index % dreams.length];
      for (var i = 1; i <= dream.length; i++) {
        if (!mounted) return;
        setState(() => _hintText = dream.substring(0, i));
        await Future.delayed(_typeDelay);
      }
      await Future.delayed(_holdDelay);
      index++;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      drawer: CustomDrawer(scaffoldKey: _scaffoldKey), // ← Drawer burada
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/homepage-bg.png',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: _buildContent(screenWidth, l10n),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double screenWidth, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Image.asset('assets/images/menu.png', width: 35),
              ),
              const Spacer(),
              const AppLogoButton(),
              const Spacer(),
              const HistoryButton(),
            ],
          ),
        ),

        const SizedBox(height: 40),

        Text(
          l10n.dreamHint,
          style: GoogleFonts.kufam(
            fontSize: 20,
            letterSpacing: 0.0,
            color: const Color(0xFFFF91B3),
            fontWeight: FontWeight.w300,
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: screenWidth * 0.7,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 9,
            textAlign: TextAlign.center,
            style: GoogleFonts.kufam(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFE0D4D4),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x5139415C),
              hintText: _isFocused ? null : _hintText,
              hintStyle: GoogleFonts.kufam(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFE0D4D4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            ),
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: screenWidth * 0.7,
          child: ElevatedButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WhoShouldInterpretScreen(dreamText: text),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xDFF0F8E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: Text(
              l10n.analyzeButton,
              style: GoogleFonts.kufam(
                fontSize: 22,
                color: const Color(0xFF81546F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
