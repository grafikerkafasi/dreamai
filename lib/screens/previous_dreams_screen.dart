import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dream_storage_service.dart';
import 'app_logo_button.dart';
import 'custom_drawer.dart'; // Drawer için import

class PreviousDreamsScreen extends StatefulWidget {
  const PreviousDreamsScreen({super.key});

  @override
  State<PreviousDreamsScreen> createState() => _PreviousDreamsScreenState();
}

class _PreviousDreamsScreenState extends State<PreviousDreamsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _dreams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDreams();
  }

  Future<void> _loadDreams() async {
    final loaded = await DreamStorageService.loadDreams();
    if (!mounted) return;
    setState(() {
      _dreams = loaded.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _deleteDream(int index) async {
    await DreamStorageService.deleteDream(_dreams.length - 1 - index);
    await _loadDreams();
  }

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
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
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
          actions: const [SizedBox(width: 55)],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _dreams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nights_stay_rounded,
                            color: Color(0xFFFF91B3), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No dreams yet.',
                          style: GoogleFonts.kufam(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: _dreams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final dream = _dreams[index];
                      return _DreamCard(
                        dreamText: dream['dream'] as String,
                        resultText: dream['result'] as String,
                        interpreter: dream['interpreter'] as String?,
                        timestamp: dream['timestamp'] as String?,
                        onDelete: () => _deleteDream(index),
                      );
                    },
                  ),
      ),
    );
  }
}

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String? _formatDate(String? isoTimestamp) {
  if (isoTimestamp == null) return null;
  final parsed = DateTime.tryParse(isoTimestamp);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return '${_monthAbbr[local.month - 1]} ${local.day}, ${local.year}';
}

String _avatarPath(String? interpreter) {
  if (interpreter == null || interpreter.isEmpty) {
    return 'assets/images/interpreters/placeholder.png';
  }
  return 'assets/images/interpreters/${interpreter.toLowerCase().replaceAll(' ', '_')}.png';
}

class _DreamCard extends StatefulWidget {
  const _DreamCard({
    required this.dreamText,
    required this.resultText,
    required this.interpreter,
    required this.timestamp,
    required this.onDelete,
  });

  final String dreamText;
  final String resultText;
  final String? interpreter;
  final String? timestamp;
  final VoidCallback onDelete;

  @override
  State<_DreamCard> createState() => _DreamCardState();
}

class _DreamCardState extends State<_DreamCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    );
    final date = _formatDate(widget.timestamp);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        onExpansionChanged: (value) => setState(() => _expanded = value),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: const Color(0x5139415C),
        collapsedBackgroundColor: const Color(0x5139415C),
        tilePadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Image.asset(
            _avatarPath(widget.interpreter),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          widget.interpreter ?? 'Unknown interpreter',
          style: GoogleFonts.kufam(
            color: const Color(0xFFFF91B3),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.dreamText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.kufam(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFFB4B4), size: 20),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onDelete,
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more_rounded,
                  color: Color(0xFFFF91B3)),
            ),
          ],
        ),
        children: [
          if (date != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                date,
                style: GoogleFonts.kufam(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Opacity(
            opacity: 0.5,
            child: Divider(thickness: 1, color: const Color(0x80E0E3E7)),
          ),
          const SizedBox(height: 8),
          Text(
            widget.resultText,
            style: GoogleFonts.kufam(
              color: const Color(0xFFE0D4D4),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
