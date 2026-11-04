import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/lesson_provider.dart';
import '../widgets/app_page_route.dart';
import '../widgets/shimmer_lesson_list.dart';
import 'admin_lesson_form_screen.dart';
import 'admin_quiz_screen.dart';

class AdminLessonsScreen extends ConsumerWidget {
  const AdminLessonsScreen({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text(
            '"${lesson.title}" and its quiz will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(apiServiceProvider).deleteLesson(lesson.id);
      ref.invalidate(lessonProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Lessons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
        onPressed: () => Navigator.of(context).push(
          SlidePageRoute(
            builder: (_) => AdminLessonFormScreen(
              nextOrderIndex:
                  (lessonsAsync.value?.length ?? 0) + 1,
            ),
          ),
        ),
      ),
      body: lessonsAsync.when(
        loading: () => const ShimmerLessonList(),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(lessonProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (lessons) => RefreshIndicator(
          onRefresh: () => ref.read(lessonProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${lesson.orderIndex}')),
                  title: Text(lesson.title),
                  subtitle: Text(
                    lesson.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          Navigator.of(context).push(
                            SlidePageRoute(
                              builder: (_) =>
                                  AdminLessonFormScreen(lesson: lesson),
                            ),
                          );
                        case 'quiz':
                          Navigator.of(context).push(
                            SlidePageRoute(
                              builder: (_) =>
                                  AdminQuizScreen(lesson: lesson),
                            ),
                          );
                        case 'delete':
                          _confirmDelete(context, ref, lesson);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'quiz', child: Text('Manage Quiz')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
