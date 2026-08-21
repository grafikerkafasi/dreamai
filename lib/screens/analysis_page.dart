import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../openai_service.dart';
import '../services/dream_storage_service.dart';
import 'app_logo_button.dart';
import 'custom_drawer.dart'; // Drawer'ı ekledik
import 'history_button.dart';
import 'paywall_screen.dart';

/// Turns an interpreter's name into its English possessive form, e.g.
/// "Freud" -> "Freud's", "Alan Watts" -> "Alan Watts'".
String _possessive(String name) {
  return name.endsWith('s') ? "$name'" : "$name's";
}

class AnalysisPage extends StatefulWidget {
  final String dreamText;
  final String interpreter;

  const AnalysisPage({
    super.key,
    required this.dreamText,
    required this.interpreter,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _result = '';
  String? _errorMessage;
  bool _loading = true;

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // Drawer için

  @override
  void initState() {
    super.initState();
    _analyzeDream();
  }

  Future<void> _analyzeDream() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await OpenAIService.analyzeDream(
        widget.dreamText,
        widget.interpreter,
      );
      await DreamStorageService.saveDream(widget.dreamText, result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on PaywallRequiredException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      final subscribed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(message: error.message),
        ),
      );
      if (!mounted) return;
      if (subscribed == true) {
        _analyzeDream();
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _shareResult() {
    if (_result.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(
        text:
            '${_possessive(widget.interpreter)} take on my dream:\n\n"$_result"\n\n— via DreamAI',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String imagePath =
        'assets/images/interpreters/${widget.interpreter.toLowerCase().replaceAll(' ', '_')}.png';

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/homepage-bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey, // Scaffold'a key atandı
        backgroundColor: Colors.transparent,
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey), // Drawer eklendi
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: GestureDetector(
              onTap: () {
                _scaffoldKey.currentState?.openDrawer(); // Drawer'ı aç
              },
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
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _errorMessage != null
                ? _ErrorState(message: _errorMessage!, onRetry: _analyzeDream)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 26,
                              color: Colors.white70,
                            ),
                            tooltip: 'Back',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Image.asset(
                            imagePath,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.interpreter,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kufam(
                            color: const Color(0xFFFAEAD6),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_possessive(widget.interpreter)} Dream Analysis',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kufam(
                            fontSize: 20,
                            color: const Color(0xFFFF91B3),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _result,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kufam(
                            fontSize: 18,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextButton.icon(
                          onPressed: _shareResult,
                          icon: const Icon(Icons.ios_share_rounded,
                              size: 26, color: Colors.white),
                          label: Text(
                            'share',
                            style: GoogleFonts.kufam(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
