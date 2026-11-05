import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'Why is a lesson locked?',
      'Lessons unlock in order. Finish the one before it to open the next lesson.',
    ),
    (
      'The video will not play. What should I do?',
      'Check your internet connection and tap Retry on the video. If it still fails, '
          'contact support with the lesson name.',
    ),
    (
      'How do I get my certificate?',
      'Complete every lesson and pass the quizzes. The certificate icon appears in the top bar.',
    ),
    (
      'How do I change my name or password?',
      'Open the menu, then Profile. Choose Edit name or Change password.',
    ),
  ];

  Future<void> _email(BuildContext context) async {
    final ok = await launchUrl(Uri.parse('mailto:${AppLinks.supportEmail}'));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email us at ${AppLinks.supportEmail}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Frequently asked questions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final (question, answer) in _faqs)
            Card(
              child: ExpansionTile(
                title: Text(question),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(answer)],
              ),
            ),
          if (AppLinks.supportEmail.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact support'),
                subtitle: Text(AppLinks.supportEmail),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _email(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
