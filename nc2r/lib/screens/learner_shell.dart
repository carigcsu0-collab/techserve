import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/qualification.dart';
import '../providers/auth_provider.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_page_route.dart';
import '../widgets/qualification_card.dart';
import 'certificate_screen.dart';
import 'lesson_detail_screen.dart';
import 'profile_screen.dart';
import 'qualification_detail_screen.dart';

/// Bottom-navigation shell for learners: Home, Explore, My Learning, Profile.
class LearnerShell extends StatefulWidget {
  const LearnerShell({super.key});

  @override
  State<LearnerShell> createState() => _LearnerShellState();
}

class _LearnerShellState extends State<LearnerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _HomeTab(),
          _ExploreTab(),
          _MyLearningTab(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'My Learning',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

Future<void> _refreshAll(WidgetRef ref) async {
  ref.invalidate(qualificationsProvider);
  await ref.read(lessonProvider.notifier).refresh();
}

/// Shows a message while loading or failing, otherwise builds [child].
Widget _asyncBody<T>({
  required AsyncValue<T> value,
  required VoidCallback onRetry,
  required Widget Function(T data) child,
}) {
  return value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(friendlyError(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
    data: child,
  );
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final lessons = ref.watch(lessonProvider);
    final qualifications = ref.watch(qualificationsProvider);

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
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                user == null ? 'Welcome' : 'Hi, ${user.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _asyncBody(
              value: lessons,
              onRetry: () => ref.invalidate(lessonProvider),
              child: (list) => _ContinueCard(
                lessons: list,
                qualifications: qualifications.value ?? const [],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Your qualifications',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _asyncBody(
              value: qualifications,
              onRetry: () => ref.invalidate(qualificationsProvider),
              child: (list) {
                final started = list.where((q) => q.completedCount > 0).toList();
                if (started.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pick a qualification in Explore to start learning.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final q in started)
                      QualificationCard(
                        qualification: q,
                        onTap: () => _openQualification(context, q),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue learning" card: the first unlocked lesson that isn't finished yet.
class _ContinueCard extends StatelessWidget {
  final List<Lesson> lessons;
  final List<Qualification> qualifications;

  const _ContinueCard({required this.lessons, required this.qualifications});

  @override
  Widget build(BuildContext context) {
    final next = lessons.where((l) => l.isUnlocked && !l.isCompleted).firstOrNull;
    final theme = Theme.of(context);

    if (next == null) {
      final done = lessons.isNotEmpty && lessons.every((l) => l.isCompleted);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: Text(done ? 'All lessons completed' : 'No lessons yet'),
          subtitle: Text(
            done
                ? 'Great work. Check My Learning for your certificates.'
                : 'Lessons will appear here once they are published.',
          ),
        ),
      );
    }

    final qualification = qualifications
        .where((q) => q.id == next.qualificationId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          SlidePageRoute(builder: (_) => LessonDetailScreen(lesson: next)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue learning',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (qualification != null) ...[
                const SizedBox(height: 4),
                Text(
                  qualification.title,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    SlidePageRoute(
                      builder: (_) => LessonDetailScreen(lesson: next),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreTab extends ConsumerWidget {
  const _ExploreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualifications = ref.watch(qualificationsProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Explore')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(qualificationsProvider);
          await ref.read(qualificationsProvider.future);
        },
        child: _asyncBody(
          value: qualifications,
          onRetry: () => ref.invalidate(qualificationsProvider),
          child: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No qualifications are available yet.')),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final q in list)
                  QualificationCard(
                    qualification: q,
                    onTap: () => _openQualification(context, q),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyLearningTab extends ConsumerWidget {
  const _MyLearningTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final qualifications = ref.watch(qualificationsProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Learning'),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(qualificationsProvider);
          await ref.read(qualificationsProvider.future);
        },
        child: _asyncBody(
          value: qualifications,
          onRetry: () => ref.invalidate(qualificationsProvider),
          child: (list) {
            final inProgress =
                list.where((q) => q.completedCount > 0 && !q.isCompleted).toList();
            final completed = list.where((q) => q.isCompleted).toList();

            if (inProgress.isEmpty && completed.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'You have not started a qualification yet. '
                        'Open Explore to begin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (inProgress.isNotEmpty) ...[
                  const _SectionTitle('In progress'),
                  for (final q in inProgress)
                    QualificationCard(
                      qualification: q,
                      onTap: () => _openQualification(context, q),
                    ),
                ],
                if (completed.isNotEmpty) ...[
                  const _SectionTitle('Completed'),
                  for (final q in completed)
                    QualificationCard(
                      qualification: q,
                      onTap: () => _openQualification(context, q),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

void _openQualification(BuildContext context, Qualification q) {
  Navigator.of(context).push(
    SlidePageRoute(
      builder: (_) => QualificationDetailScreen(
        qualificationId: q.id,
        fallbackTitle: q.title,
      ),
    ),
  );
}
