import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.school, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'TechServe',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _version.isEmpty ? 'Version' : 'Version $_version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                if (AppLinks.privacyPolicyUrl.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _open(AppLinks.privacyPolicyUrl),
                  ),
                  const Divider(height: 1),
                ],
                if (AppLinks.termsUrl.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of service'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _open(AppLinks.termsUrl),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Open-source licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'TechServe',
                    applicationVersion: _version,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
