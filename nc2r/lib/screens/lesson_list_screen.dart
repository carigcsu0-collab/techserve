import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/lesson_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../services/error_messages.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_page_route.dart';
import '../widgets/lesson_tile.dart';
import '../widgets/shimmer_lesson_list.dart';
import 'certificate_screen.dart';
import 'lesson_detail_screen.dart';

class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('TechServe'),
        actions: [
          if (user?.certificateUrl != null)
            IconButton(
              icon: const Icon(Icons.workspace_premium),
              tooltip: 'View certificate',
              onPressed: () => Navigator.of(context).push(
                FadePageRoute(
                  builder: (_) =>
                      CertificateScreen(certificateUrl: user!.certificateUrl!),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: lessonsAsync.when(
        loading: () => const ShimmerLessonList(),
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
        data: (lessons) => RefreshIndicator(
          onRefresh: () => ref.read(lessonProvider.notifier).refresh(),
          child: AnimationLimiter(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50,
                    child: FadeInAnimation(
                      child: LessonTile(
                        lesson: lesson,
                        onTap: () {
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
                          Navigator.of(context).push(
                            SlidePageRoute(
                              builder: (_) =>
                                  LessonDetailScreen(lesson: lesson),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
