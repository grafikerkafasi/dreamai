import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_routes.dart';

class CustomDrawer extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const CustomDrawer({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Header with Logo
          Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Center(
              child: GestureDetector(
                onTap: () => _replaceWith(context, AppRoutes.dream),
                child: Image.asset('assets/images/logo.png',
                    width: 150, height: 50),
              ),
            ),
          ),

          // Menu Buttons
          Column(
            children: [
              _buildDrawerButton(
                text: 'Tell your dream',
                onTap: () => _replaceWith(context, AppRoutes.dream),
              ),
              _divider(),
              _buildDrawerButton(
                text: "My past dreams",
                onTap: () => _push(context, AppRoutes.previousDreams),
              ),
              _divider(),
              _buildDrawerButton(
                text: 'Contact',
                onTap: () => _push(context, AppRoutes.contact),
              ),
              _divider(),
              _buildDrawerButton(
                text: 'Privacy Policy',
                onTap: () => _push(context, AppRoutes.privacy),
              ),
              _divider(),
              _buildDrawerButton(
                text: 'Terms And Conditions',
                onTap: () => _push(context, AppRoutes.terms),
              ),
            ],
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Text(
              'Sanai ©',
              style: GoogleFonts.kufam(
                color: Color(0xFFEFF5E6),
                fontSize: 10,
                fontWeight: FontWeight.w200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerButton(
      {required String text, required VoidCallback onTap}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        text,
        style: GoogleFonts.kufam(
          color: Color(0xFFEFF5E6),
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(routeName);
  }

  void _replaceWith(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (_) => false);
  }

  Widget _divider() {
    return Opacity(
      opacity: 0.5,
      child: Divider(
        thickness: 1,
        height: 1,
        indent: 24,
        endIndent: 24,
        color: Color(0x80E0E3E7),
      ),
    );
  }
}
