import 'package:flutter/material.dart';
import '../services/contact_service.dart';
import 'info_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _openingMail = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _openingMail = true);
    try {
      await ContactService.send(
        name: _name.text.trim(),
        email: _email.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      _formKey.currentState?.reset();
      _name.clear();
      _email.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message has been sent. Thank you!')),
      );
    } on ContactException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _openingMail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DreamPageScaffold(
      title: 'Contact',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Contact', style: DreamPageStyles.heading),
              const SizedBox(height: 12),
              Text(
                  'Share feedback, questions, or ideas. Your message will be sent securely to our contact inbox.',
                  style: DreamPageStyles.body),
              const SizedBox(height: 28),
              _field(
                  _name,
                  'Name',
                  (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your name.'
                      : null),
              const SizedBox(height: 18),
              _field(
                  _email,
                  'Email',
                  (value) => value == null || !value.contains('@')
                      ? 'Please enter a valid email address.'
                      : null,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 18),
              _field(
                  _message,
                  'Message',
                  (value) => value == null || value.trim().isEmpty
                      ? 'Please write a message.'
                      : null,
                  maxLines: 6),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _openingMail ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xDFF0F8E9),
                  foregroundColor: const Color(0xFF81546F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_openingMail ? 'Sending…' : 'Send email'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      String? Function(String?) validator,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: DreamPageStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DreamPageStyles.subheading,
        filled: true,
        fillColor: const Color(0x5139415C),
        errorStyle: const TextStyle(color: Color(0xFFFFB4B4)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
    );
  }
}
