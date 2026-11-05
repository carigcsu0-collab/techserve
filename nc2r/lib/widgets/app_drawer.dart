import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_links.dart';
import '../providers/auth_provider.dart';
import '../screens/about_screen.dart';
import '../screens/help_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/rate_share_screen.dart';
import '../screens/settings_screen.dart';
import 'app_page_route.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);

    void open(Widget Function(BuildContext) builder) {
      Navigator.of(context).pop();
      Navigator.of(context).push(SlidePageRoute(builder: builder));
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.name.isNotEmpty ?? false)
                      ? user!.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
              ),
              accountName: Text(user?.name ?? ''),
              accountEmail: Text(user?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => open((_) => const ProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('My progress'),
              onTap: () => open((_) => const ProgressScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => open((_) => const SettingsScreen()),
            ),
            if (AppLinks.storeUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Rate & share'),
                onTap: () => open((_) => const RateShareScreen()),
              ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & support'),
              onTap: () => open((_) => const HelpScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () => open((_) => const AboutScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
