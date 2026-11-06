import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/qualification.dart';
import '../providers/api_provider.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import '../widgets/app_page_route.dart';
import '../widgets/shimmer_lesson_list.dart';
import 'admin_lesson_form_screen.dart';
import 'admin_quiz_screen.dart';

const int _filterAll = -1;
const int _filterUnassigned = 0;

/// Lessons tab of the admin shell: publish toggle, qualification filter,
/// and drag-to-reorder within a single qualification.
class AdminLessonsTab extends ConsumerStatefulWidget {
  const AdminLessonsTab({super.key});

  @override
  ConsumerState<AdminLessonsTab> createState() => _AdminLessonsTabState();
}

class _AdminLessonsTabState extends ConsumerState<AdminLessonsTab> {
  /// One of [_filterAll], [_filterUnassigned], or a qualification id.
  int _filter = _filterAll;

  /// Ids in the order the admin just dragged them to, until the save completes.
  List<int>? _pendingOrder;

  Future<void> _togglePublished(Lesson lesson, bool value) async {
    try {
      await ref.read(apiServiceProvider).setLessonPublished(lesson.id, value);
      ref.invalidate(lessonProvider);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _reorder(
      int? qualificationId, List<Lesson> group, int oldIndex, int newIndex) async {
    final ids = group.map((l) => l.id).toList();
    if (newIndex > oldIndex) newIndex -= 1;
    ids.insert(newIndex, ids.removeAt(oldIndex));

    setState(() => _pendingOrder = ids);
    try {
      await ref.read(apiServiceProvider).reorderLessons(qualificationId, ids);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
      ref.invalidate(lessonProvider);
    }
  }

  Future<void> _confirmDelete(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson?'),
        content:
            Text('"${lesson.title}" and its quiz will be permanently removed.'),
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
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiServiceProvider).deleteLesson(lesson.id);
      ref.invalidate(lessonProvider);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  List<Lesson> _visibleLessons(List<Lesson> all) {
    final filtered = all.where((l) {
      if (_filter == _filterAll) return true;
      if (_filter == _filterUnassigned) return l.qualificationId == null;
      return l.qualificationId == _filter;
    }).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final order = _pendingOrder;
    if (order == null || _filter == _filterAll) return filtered;
    final byId = {for (final l in filtered) l.id: l};
    return [for (final id in order) if (byId[id] != null) byId[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(lessonProvider);
    final qualifications =
        ref.watch(adminQualificationsProvider).value ?? const <Qualification>[];
    final canReorder = _filter != _filterAll;

    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
        onPressed: () {
          final all = lessonsAsync.value ?? const <Lesson>[];
          // order_index is unique across all lessons, so count from the highest used value.
          final highest = all.fold<int>(0, (m, l) => l.orderIndex > m ? l.orderIndex : m);
          Navigator.of(context).push(
            SlidePageRoute(
              builder: (_) => AdminLessonFormScreen(
                nextOrderIndex: highest + 1,
                qualificationId: _filter > 0 ? _filter : null,
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _filterChip('All', _filterAll),
                _filterChip('Unassigned', _filterUnassigned),
                for (final q in qualifications) _filterChip(q.title, q.id),
              ],
            ),
          ),
          Expanded(
            child: lessonsAsync.when(
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
              data: (lessons) {
                final visible = _visibleLessons(lessons);
                if (visible.isEmpty) {
                  return const Center(
                    child: Text('No lessons in this group yet.'),
                  );
                }
                if (canReorder) {
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 96, top: 4),
                    buildDefaultDragHandles: false,
                    itemCount: visible.length,
                    onReorder: (o, n) => _reorder(
                      _filter == _filterUnassigned ? null : _filter,
                      visible,
                      o,
                      n,
                    ),
                    itemBuilder: (context, index) {
                      final lesson = visible[index];
                      return _LessonCard(
                        key: ValueKey(lesson.id),
                        lesson: lesson,
                        dragIndex: index,
                        onPublishedChanged: (v) => _togglePublished(lesson, v),
                        onEdit: () => _openForm(lesson),
                        onQuiz: () => _openQuiz(lesson),
                        onDelete: () => _confirmDelete(lesson),
                      );
                    },
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(lessonProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96, top: 4),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final lesson = visible[index];
                      return _LessonCard(
                        lesson: lesson,
                        onPublishedChanged: (v) => _togglePublished(lesson, v),
                        onEdit: () => _openForm(lesson),
                        onQuiz: () => _openQuiz(lesson),
                        onDelete: () => _confirmDelete(lesson),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  void _openForm(Lesson lesson) {
    Navigator.of(context).push(
      SlidePageRoute(builder: (_) => AdminLessonFormScreen(lesson: lesson)),
    );
  }

  void _openQuiz(Lesson lesson) {
    Navigator.of(context).push(
      SlidePageRoute(builder: (_) => AdminQuizScreen(lesson: lesson)),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final int? dragIndex;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onEdit;
  final VoidCallback onQuiz;
  final VoidCallback onDelete;

  const _LessonCard({
    super.key,
    required this.lesson,
    required this.onPublishedChanged,
    required this.onEdit,
    required this.onQuiz,
    required this.onDelete,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text('${lesson.orderIndex}')),
        title: Text(lesson.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!lesson.isPublished)
              Text(
                'Draft: hidden from learners',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: lesson.isPublished, onChanged: onPublishedChanged),
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    onEdit();
                  case 'quiz':
                    onQuiz();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'quiz', child: Text('Manage Quiz')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.drag_handle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
