import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_logo_button.dart';
import 'custom_drawer.dart';
import 'history_button.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<InfoSection> sections;

  @override
  Widget build(BuildContext context) {
    return DreamPageScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        children: [
          Text(title, style: DreamPageStyles.heading),
          const SizedBox(height: 28),
          for (final section in sections) ...[
            Text(section.heading, style: DreamPageStyles.subheading),
            const SizedBox(height: 10),
            Text(section.body, style: DreamPageStyles.body),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }
}

class InfoSection {
  const InfoSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

class DreamPageScaffold extends StatefulWidget {
  const DreamPageScaffold(
      {super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<DreamPageScaffold> createState() => _DreamPageScaffoldState();
}

class _DreamPageScaffoldState extends State<DreamPageScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/homepage-bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Open menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Image.asset('assets/images/menu.png', width: 35),
          ),
          title: const AppLogoButton(),
          actions: const [HistoryButton()],
        ),
        body: widget.child,
      ),
    );
  }
}

abstract final class DreamPageStyles {
  static final heading = GoogleFonts.kufam(
    color: const Color(0xFFFF91B3),
    fontSize: 24,
    fontWeight: FontWeight.w400,
  );
  static final subheading = GoogleFonts.kufam(
    color: const Color(0xFFFAEAD6),
    fontSize: 17,
    fontWeight: FontWeight.w400,
  );
  static final body = GoogleFonts.kufam(
    color: const Color(0xFFE0D4D4),
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w300,
  );
}
