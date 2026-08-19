import 'package:flutter/material.dart';
import '../app_routes.dart';

/// The logo shown in every AppBar; tapping it always returns to the dream
/// entry screen, clearing the navigation stack the same way the drawer's
/// "Tell your dream" entry does.
class AppLogoButton extends StatelessWidget {
  const AppLogoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.dream, (route) => false),
      child: Image.asset('assets/images/logo.png', width: 172, height: 58),
    );
  }
}
