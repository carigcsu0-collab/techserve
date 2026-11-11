import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qualification.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import '../widgets/app_page_route.dart';
import '../widgets/lesson_tile.dart';
import '../widgets/shimmer_lesson_list.dart';
import 'lesson_detail_screen.dart';
import 'exam_screen.dart';

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
              if (data.exams.pre != null)
                _ExamCard(
                  title: 'Pre-Test',
                  subtitle: data.exams.pre!.taken
                      ? 'Done — score ${data.exams.pre!.bestScore ?? 0}%'
                      : 'Required before you can start the lessons '
                          '(${data.exams.pre!.items} items)',
                  icon: Icons.fact_check_outlined,
                  done: data.exams.pre!.taken,
                  buttonLabel: data.exams.pre!.taken ? 'Retake' : 'Start',
                  onPressed: () => _openExam(context, ref, 'pre'),
                ),
              for (final lesson in data.lessons)
                LessonTile(
                  lesson: lesson,
                  onTap: () async {
                    if (!lesson.isUnlocked) {
                      final needsPre =
                          data.exams.pre != null && !data.exams.pre!.taken;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            needsPre
                                ? 'Take the Pre-Test first to unlock the lessons.'
                                : 'Complete the previous lesson to unlock this one.',
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
              if (data.exams.post != null)
                _ExamCard(
                  title: 'Post-Test',
                  subtitle: !data.exams.post!.available
                      ? 'Finish all lessons to unlock (${data.exams.post!.items} items)'
                      : data.exams.post!.taken
                          ? 'Best score ${data.exams.post!.bestScore ?? 0}%'
                              '${data.exams.post!.passed ? ' — passed' : ''}'
                          : '${data.exams.post!.items} items',
                  icon: Icons.workspace_premium_outlined,
                  done: data.exams.post!.passed,
                  buttonLabel: data.exams.post!.taken ? 'Retake' : 'Start',
                  onPressed: data.exams.post!.available
                      ? () => _openExam(context, ref, 'post')
                      : null,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExam(BuildContext context, WidgetRef ref, String type) async {
    await Navigator.of(context).push(
      SlidePageRoute(
        builder: (_) =>
            ExamScreen(qualificationId: qualificationId, type: type),
      ),
    );
    ref.invalidate(qualificationDetailProvider(qualificationId));
    ref.invalidate(qualificationsProvider);
  }
}

class _ExamCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _ExamCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : icon,
            color: done ? Colors.green : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
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
