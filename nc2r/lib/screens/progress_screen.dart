import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My progress')),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(lessonProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) => _ProgressBody(lessons: items),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final List<Lesson> lessons;

  const _ProgressBody({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = lessons.where((l) => l.isCompleted).length;
    final total = lessons.length;
    final fraction = total == 0 ? 0.0 : completed / total;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0
                      ? 'No lessons yet'
                      : '$completed of $total lessons completed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(fraction * 100).round()}% complete'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final lesson in lessons)
          ListTile(
            leading: Icon(
              lesson.isCompleted
                  ? Icons.check_circle
                  : lesson.isUnlocked
                  ? Icons.radio_button_unchecked
                  : Icons.lock_outline,
              color: lesson.isCompleted
                  ? Colors.green
                  : theme.colorScheme.outline,
            ),
            title: Text(lesson.title),
            subtitle: Text(
              lesson.isCompleted
                  ? 'Completed'
                  : lesson.isUnlocked
                  ? 'In progress'
                  : 'Locked',
            ),
          ),
      ],
    );
  }
}
