import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../providers/lesson_provider.dart';
import '../widgets/app_page_route.dart';
import '../widgets/lesson_avatar.dart';
import '../widgets/lesson_media.dart';
import '../widgets/tap_scale.dart';
import 'quiz_screen.dart';

class LessonDetailScreen extends ConsumerWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `lesson` is a snapshot from when this screen was pushed. Re-read the
    // live copy from lessonProvider so that passing the quiz and popping
    // back here (rather than all the way to the list) immediately shows
    // "Completed" / "Retake Quiz" instead of stale pre-quiz state.
    final lessons = ref.watch(lessonProvider).value;
    final liveLesson =
        lessons?.firstWhere((l) => l.id == lesson.id, orElse: () => lesson) ??
            lesson;

    return Scaffold(
      appBar: AppBar(title: Text('Lesson ${liveLesson.orderIndex}')),
      body: Column(
        children: [
          LessonMedia(lesson: liveLesson),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'lesson-avatar-${liveLesson.id}',
                        child: LessonAvatar(lesson: liveLesson, radius: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(liveLesson.title,
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(liveLesson.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                            parent: animation, curve: Curves.easeOutBack),
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                    child: liveLesson.isCompleted
                        ? Chip(
                            key: const ValueKey('completed'),
                            avatar: const Icon(Icons.check_circle,
                                size: 18, color: Colors.green),
                            label: const Text('Completed'),
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                          )
                        : const SizedBox.shrink(key: ValueKey('incomplete')),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.quiz),
                    label: Text(
                        liveLesson.isCompleted ? 'Retake Quiz' : 'Take Quiz'),
                    onPressed: () => Navigator.of(context).push(
                      SlidePageRoute(
                        builder: (_) => QuizScreen(lesson: liveLesson),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
