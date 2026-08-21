import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
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
  final GlobalKey _shareCardKey = GlobalKey();
  bool _sharing = false;

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
      await DreamStorageService.saveDream(
        widget.dreamText,
        result,
        widget.interpreter,
      );
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

  Future<void> _shareResult() async {
    if (_result.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(
        pixelRatio: pixelRatio < 2.5 ? 2.5 : pixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/dreamai_analysis.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '${_possessive(widget.interpreter)} take on my dream — via DreamAI',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imagePath =
        'assets/images/interpreters/${widget.interpreter.toLowerCase().replaceAll(' ', '_')}.png';

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/homepage-bg.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey, // Scaffold'a key atandı
        backgroundColor: Colors.transparent,
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey), // Drawer eklendi
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 17),
          child: Padding(
            padding: const EdgeInsets.only(top: 17),
            child: AppBar(
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
          ),
        ),
        body: _loading
            ? const Center(child: _AnalyzingProgress())
            : _errorMessage != null
                ? _ErrorState(message: _errorMessage!, onRetry: _analyzeDream)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        RepaintBoundary(
                          key: _shareCardKey,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 28),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              image: const DecorationImage(
                                image:
                                    AssetImage('assets/images/homepage-bg.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Column(
                              children: [
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
                                  'My dream analysis by ${widget.interpreter}',
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
                                const SizedBox(height: 24),
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 26,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 26,
                                color: Colors.white70,
                              ),
                              tooltip: 'Back',
                            ),
                            Expanded(
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: _sharing ? null : _shareResult,
                                  icon: _sharing
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.ios_share_rounded,
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// A pill-shaped progress bar that eases toward ~92% over an estimated
/// wait (the backend can take 30-50s to wake from an idle sleep, on top
/// of the model's own latency) and holds there until the real response
/// arrives, so users see steady motion instead of a bare spinner.
class _AnalyzingProgress extends StatefulWidget {
  const _AnalyzingProgress();

  @override
  State<_AnalyzingProgress> createState() => _AnalyzingProgressState();
}

class _AnalyzingProgressState extends State<_AnalyzingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress =
                  Curves.easeOut.transform(_controller.value) * 0.92;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: const Color(0xFF1C1030),
                      border: Border.all(
                        color: const Color(0xFFF4B183),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF4B183).withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: width * progress,
                          height: 22,
                          child: Image.asset(
                            'assets/images/homepage-bg.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Interpreting your dream…',
            textAlign: TextAlign.center,
            style: GoogleFonts.kufam(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
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
