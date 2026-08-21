import 'package:flutter/material.dart';
import '../app_routes.dart';

/// Quick shortcut to "My past dreams", shown in the top-right corner of the
/// AppBar to mirror the hamburger menu on the top-left.
class HistoryButton extends StatelessWidget {
  const HistoryButton({super.key});

  static const _color = Color(0xFFFDEAD9);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'My past dreams',
      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.previousDreams),
      icon: const Icon(Icons.history_rounded, color: _color, size: 32),
    );
  }
}
