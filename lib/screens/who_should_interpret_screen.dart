import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../openai_service.dart';
import 'analysis_page.dart';
import 'app_logo_button.dart';
import 'custom_drawer.dart';
import 'history_button.dart';

class WhoShouldInterpretScreen extends StatefulWidget {
  final String dreamText;

  const WhoShouldInterpretScreen({super.key, required this.dreamText});

  @override
  State<WhoShouldInterpretScreen> createState() =>
      _WhoShouldInterpretScreenState();
}

class _WhoShouldInterpretScreenState extends State<WhoShouldInterpretScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UsageInfo? _usage;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  void _refreshUsage() {
    OpenAIService.getUsage().then((usage) {
      if (mounted) setState(() => _usage = usage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dreamText = widget.dreamText;
    final interpreters = OpenAIService.getAvailableInterpreters();
    final imageMap = {
      'Nietzsche': 'assets/images/interpreters/nietzsche.png',
      'Freud': 'assets/images/interpreters/freud.png',
      'Jung': 'assets/images/interpreters/jung.png',
      'Yalom': 'assets/images/interpreters/yalom.png',
      'Alan Watts': 'assets/images/interpreters/alan_watts.png',
      'Schopenhauer': 'assets/images/interpreters/schopenhauer.png',
      'Fortune Teller': 'assets/images/interpreters/fortune_teller.png',
      'Viktor Frankl': 'assets/images/interpreters/viktor_frankl.png',
      'Carl Rogers': 'assets/images/interpreters/carl_rogers.png',
      'Dostoyevsky': 'assets/images/interpreters/dostoyevsky.png',
      'Buddha': 'assets/images/interpreters/buddha.png',
      'Jesus': 'assets/images/interpreters/jesus.png',
      'Imam': 'assets/images/interpreters/imam.png',
      'Rabbi': 'assets/images/interpreters/rabbi.png',
      'Hindu Guru': 'assets/images/interpreters/hindu_guru.png',
    };

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/homepage-bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey),
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 17),
          child: Padding(
            padding: const EdgeInsets.only(top: 17),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 20),
                child: GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Image.asset(
                    'assets/images/menu.png',
                    width: 35,
                    height: 35,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              title: const Center(child: AppLogoButton()),
              actions: const [HistoryButton()],
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/empty_bg.png',
                fit: BoxFit.fill,
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Choose an Interpreter',
                  style: GoogleFonts.kufam(
                    color: const Color(0xFFFF91B3),
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (_usage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _usage!.subscribed
                        ? '${_usage!.remaining} dreams left this month'
                        : '${_usage!.remaining} free dreams left',
                    style: GoogleFonts.kufam(
                      color: const Color(0xFFFAEAD6),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: interpreters.length,
                    itemBuilder: (context, index) {
                      final name = interpreters[index];
                      final imagePath = imageMap[name] ??
                          'assets/images/interpreters/placeholder.png';

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalysisPage(
                                dreamText: dreamText,
                                interpreter: name,
                              ),
                            ),
                          );
                          if (mounted) _refreshUsage();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.asset(
                                imagePath,
                                width: 160,
                                height: 160,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kufam(
                                color: const Color(0xFFFAEAD6),
                                fontSize: 16,
                                fontWeight: FontWeight.w100,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
