import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        const SnackBar(content: Text('Could not open your mail app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DreamPageScaffold(
      title: 'Contact',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contact', style: DreamPageStyles.heading),
            const SizedBox(height: 12),
            Text(
              'We value your feedback and ideas — they help us make DreamAI better for everyone. Reach out anytime and we\'ll get back to you.',
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
              child: const Text('Contact Us'),
            ),
          ],
        ),
      ),
    );
  }
}
