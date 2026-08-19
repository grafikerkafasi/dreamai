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
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                      onDelete: () => _deleteDream(index),
                    );
                  },
                ),
      ),
    );
  }
}

class _DreamCard extends StatelessWidget {
  const _DreamCard({
    required this.dreamText,
    required this.resultText,
    required this.onDelete,
  });

  final String dreamText;
  final String resultText;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: shape,
        collapsedShape: shape,
        backgroundColor: const Color(0x5139415C),
        collapsedBackgroundColor: const Color(0x5139415C),
        iconColor: const Color(0xFFFF91B3),
        collapsedIconColor: const Color(0xFFFF91B3),
        tilePadding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: const Icon(Icons.auto_awesome,
            color: Color(0xFFFF91B3), size: 20),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dreamText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kufam(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFFB4B4), size: 22),
              splashRadius: 20,
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          Opacity(
            opacity: 0.5,
            child: Divider(thickness: 1, color: const Color(0x80E0E3E7)),
          ),
          const SizedBox(height: 8),
          Text(
            resultText,
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
