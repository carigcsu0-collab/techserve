import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).select(value);
                }
              },
              child: Column(
                children: [
                  for (final option in ThemeMode.values) ...[
                    RadioListTile<ThemeMode>(
                      value: option,
                      title: Text(_label(option)),
                    ),
                    if (option != ThemeMode.values.last)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Use device setting',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
