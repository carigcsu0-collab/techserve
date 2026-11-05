import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qualification.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import '../widgets/app_page_route.dart';
import '../widgets/lesson_tile.dart';
import '../widgets/shimmer_lesson_list.dart';
import 'lesson_detail_screen.dart';

class QualificationDetailScreen extends ConsumerWidget {
  final int qualificationId;
  final String? fallbackTitle;

  const QualificationDetailScreen({
    super.key,
    required this.qualificationId,
    this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(qualificationDetailProvider(qualificationId));

    return Scaffold(
      appBar: AppBar(title: Text(fallbackTitle ?? 'Qualification')),
      body: detail.when(
        loading: () => const ShimmerLessonList(),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(qualificationDetailProvider(qualificationId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(qualificationDetailProvider(qualificationId));
            await ref.read(qualificationDetailProvider(qualificationId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Header(qualification: data.qualification),
              for (final lesson in data.lessons)
                LessonTile(
                  lesson: lesson,
                  onTap: () async {
                    if (!lesson.isUnlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Complete the previous lesson to unlock this one.',
                          ),
                        ),
                      );
                      return;
                    }
                    await Navigator.of(context).push(
                      SlidePageRoute(
                        builder: (_) => LessonDetailScreen(lesson: lesson),
                      ),
                    );
                    // Pick up the newly unlocked lesson and updated progress.
                    ref.invalidate(qualificationDetailProvider(qualificationId));
                    ref.invalidate(qualificationsProvider);
                  },
                ),
              if (data.lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Lessons for this qualification are coming soon.'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Qualification qualification;

  const _Header({required this.qualification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = qualification;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: q.progress, minHeight: 8),
          const SizedBox(height: 8),
          Text(
            q.isCompleted
                ? 'Completed. All ${q.lessonCount} lessons passed.'
                : '${q.completedCount} of ${q.lessonCount} lessons completed',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
