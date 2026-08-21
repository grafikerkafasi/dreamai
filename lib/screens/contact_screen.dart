import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import 'info_screen.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static final Uri _mailUri = Uri(
    scheme: 'mailto',
    path: 'a.yasiny.yilmaz@gmail.com',
    queryParameters: {'subject': 'DreamAI Feedback'},
  );

  Future<void> _openMail(BuildContext context) async {
    final launched =
        await launchUrl(_mailUri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mailAppError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DreamPageScaffold(
      title: l10n.contactTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.contactTitle, style: DreamPageStyles.heading),
            const SizedBox(height: 12),
            Text(
              l10n.contactBody,
              style: DreamPageStyles.body,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => _openMail(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xDFF0F8E9),
                foregroundColor: const Color(0xFF81546F),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.contactUsButton),
            ),
          ],
        ),
      ),
    );
  }
}
