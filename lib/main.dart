import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_routes.dart';
import 'screens/who_should_interpret_screen.dart';
import 'screens/previous_dreams_screen.dart';
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
      initialRoute: AppRoutes.dream,
      routes: {
        AppRoutes.dream: (context) => const DreamPage(),
        AppRoutes.previousDreams: (context) => const PreviousDreamsScreen(),
        AppRoutes.contact: (context) => const ContactScreen(),
        AppRoutes.privacy: (context) => const InfoScreen(
              title: 'Privacy Policy',
              sections: [
                InfoSection(
                  heading: 'Your dreams stay on your device',
                  body:
                      'In demo mode, dream entries and demo analyses are stored only in this app on your device. They are not sent to us or to an AI service.',
                ),
                InfoSection(
                  heading: 'When AI mode is enabled',
                  body:
                      'If you later enable AI mode, the dream text and selected interpretation style are sent to the analysis service to produce a response. Do not include sensitive personal information.',
                ),
                InfoSection(
                  heading: 'Your choices',
                  body:
                      'You can remove a saved dream at any time from My past dreams. This policy will be updated before any additional data collection is introduced.',
                ),
              ],
            ),
        AppRoutes.terms: (context) => const InfoScreen(
              title: 'Terms and Conditions',
              sections: [
                InfoSection(
                  heading: 'For reflection, not diagnosis',
                  body:
                      'DreamAI offers creative and reflective interpretations for entertainment. It is not medical, mental-health, legal, or professional advice.',
                ),
                InfoSection(
                  heading: 'Use with care',
                  body:
                      'Please avoid entering information that is highly sensitive or belongs to someone else. If a dream raises urgent concerns, contact a qualified professional or local emergency service.',
                ),
              ],
            ),
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
  static const _placeholderDreams = [
    'A large fairy bird caught me and brought me up to the clouds.',
    'I was swimming through an ocean made of stars.',
    'My childhood home turned into a maze of mirrors.',
    'I could fly, but only a few inches off the ground.',
    'A stranger handed me a key that glowed in the dark.',
  ];
  static const _typeDelay = Duration(milliseconds: 40);
  static const _holdDelay = Duration(milliseconds: 1400);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isFocused = false;
  String _hintText = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    _runPlaceholderTypewriter();
  }

  Future<void> _runPlaceholderTypewriter() async {
    var index = 0;
    while (mounted) {
      final dream = _placeholderDreams[index % _placeholderDreams.length];
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: CustomDrawer(scaffoldKey: _scaffoldKey), // ← Drawer burada
      body: Stack(
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
                    child: _buildContent(screenWidth),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double screenWidth) {
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
          'Tell me your dream...',
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
              'analyze',
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
