import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/interpreter_prompts.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show routeObserver;
import '../openai_service.dart';
import 'analysis_page.dart';
import 'app_logo_button.dart';
import 'custom_drawer.dart';
import 'history_button.dart';

enum _InterpreterCategory { all, thinkers, celebrities, mystics }

const _thinkerNames = [
  'Nietzsche',
  'Freud',
  'Jung',
  'Yalom',
  'Alan Watts',
  'Schopenhauer',
  'Viktor Frankl',
  'Carl Rogers',
  'Dostoyevsky',
];
const _mysticNames = [
  'Buddha',
  'Jesus',
  'Imam',
  'Rabbi',
  'Hindu Guru',
  'Fortune Teller',
];
const _celebrityNames = [
  'Keanu Reeves',
  'Dwayne Johnson',
  'Freddie Mercury',
  'Emma Watson',
  'Bruce Lee',
];

class WhoShouldInterpretScreen extends StatefulWidget {
  final String dreamText;

  const WhoShouldInterpretScreen({super.key, required this.dreamText});

  @override
  State<WhoShouldInterpretScreen> createState() =>
      _WhoShouldInterpretScreenState();
}

class _WhoShouldInterpretScreenState extends State<WhoShouldInterpretScreen>
    with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UsageInfo? _usage;
  _InterpreterCategory _category = _InterpreterCategory.all;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when a route pushed on top of this one (the paywall, the
  // credits screen) is popped and this screen is visible again — refresh
  // so a subscribe/purchase made there is reflected here without needing
  // to leave and re-enter this screen.
  @override
  void didPopNext() => _refreshUsage();

  void _refreshUsage() {
    OpenAIService.getUsage().then((usage) {
      if (mounted) setState(() => _usage = usage);
    });
  }

  bool _matchesCategory(String name) {
    switch (_category) {
      case _InterpreterCategory.all:
        return true;
      case _InterpreterCategory.thinkers:
        return _thinkerNames.contains(name);
      case _InterpreterCategory.celebrities:
        return _celebrityNames.contains(name);
      case _InterpreterCategory.mystics:
        return _mysticNames.contains(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dreamText = widget.dreamText;
    final interpreters =
        OpenAIService.getAvailableInterpreters().where(_matchesCategory).toList();
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
      'Keanu Reeves': 'assets/images/interpreters/keanu_reeves.png',
      'Dwayne Johnson': 'assets/images/interpreters/dwayne_johnson.png',
      'Freddie Mercury': 'assets/images/interpreters/freddie_mercury.png',
      'Emma Watson': 'assets/images/interpreters/emma_watson.png',
      'Bruce Lee': 'assets/images/interpreters/bruce_lee.png',
    };
    final tabLabels = {
      _InterpreterCategory.all: l10n.interpreterTabAll,
      _InterpreterCategory.thinkers: l10n.interpreterTabThinkers,
      _InterpreterCategory.celebrities: l10n.interpreterTabCelebrities,
      _InterpreterCategory.mystics: l10n.interpreterTabMystics,
    };

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/empty_bg.png'),
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
        body: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.chooseInterpreter,
              style: GoogleFonts.kufam(
                color: const Color(0xFFFF91B3),
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CategoryTabBar(
                labels: tabLabels,
                selected: _category,
                onSelect: (category) => setState(() => _category = category),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          interpreterDisplayName(l10n, name),
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
        bottomNavigationBar: _usage == null
            ? null
            : Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.18),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _usage!.subscribed
                          ? l10n.dreamsLeftThisMonth(_usage!.remaining)
                          : l10n.freeDreamsLeft(_usage!.remaining),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.kufam(
                        color: const Color(0xFFFAEAD6),
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CategoryTabBar extends StatelessWidget {
  final Map<_InterpreterCategory, String> labels;
  final _InterpreterCategory selected;
  final ValueChanged<_InterpreterCategory> onSelect;

  const _CategoryTabBar({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: labels.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3A2B52)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kufam(
                    color: const Color(0xFFFAEAD6),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
