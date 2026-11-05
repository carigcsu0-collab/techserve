import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';

class RateShareScreen extends StatelessWidget {
  const RateShareScreen({super.key});

  Future<void> _rate(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(AppLinks.storeUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store page.')),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppLinks.storeUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied. Share it with your classmates!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStore = AppLinks.storeUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Rate & share')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.star_rounded,
            size: 72,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Enjoying TechServe?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasStore
                ? 'A rating helps other learners find the app.'
                : 'The store page is not available yet.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (hasStore) ...[
            FilledButton.icon(
              onPressed: () => _rate(context),
              icon: const Icon(Icons.star_outline),
              label: const Text('Rate on Google Play'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _copyLink(context),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Copy share link'),
            ),
          ],
        ],
      ),
    );
  }
}
