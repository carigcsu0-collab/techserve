import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/qualification.dart';
import 'api_provider.dart';

class LessonNotifier extends AsyncNotifier<List<Lesson>> {
  @override
  Future<List<Lesson>> build() {
    return ref.read(apiServiceProvider).fetchLessons();
  }

  /// Refreshes from the server. On failure, keeps the last good (possibly
  /// optimistic) data on screen instead of replacing it with an error state
  /// — losing the just-applied unlock over a transient network blip would
  /// be worse than briefly showing slightly-stale data. The error is still
  /// reported so callers can react if they need to.
  Future<void> refresh() async {
    final previous = state.value;
    final result = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).fetchLessons(),
    );
    state = result.hasError && previous != null
        ? AsyncValue.data(previous)
        : result;
  }

  /// Optimistically mark [lessonId] completed and unlock the next lesson in
  /// the same qualification. Lessons in other qualifications are unaffected.
  /// [refresh] then pulls the authoritative list (freshly unlocked lessons
  /// include media_url).
  void applyQuizPass(int lessonId) {
    final lessons = state.value;
    if (lessons == null) return;

    final index = lessons.indexWhere((l) => l.id == lessonId);
    if (index < 0) return;

    final qualificationId = lessons[index].qualificationId;
    final updated = [...lessons];
    updated[index] = updated[index].copyWith(isCompleted: true);

    for (var i = index + 1; i < updated.length; i++) {
      if (updated[i].qualificationId == qualificationId) {
        updated[i] = updated[i].copyWith(isUnlocked: true);
        break;
      }
    }
    state = AsyncValue.data(updated);
    ref.invalidate(qualificationsProvider);
  }
}

final lessonProvider =
    AsyncNotifierProvider<LessonNotifier, List<Lesson>>(LessonNotifier.new);

final qualificationsProvider = FutureProvider<List<Qualification>>((ref) {
  return ref.read(apiServiceProvider).fetchQualifications();
});

final qualificationDetailProvider = FutureProvider.family<
    ({Qualification qualification, List<Lesson> lessons}), int>((ref, id) {
  return ref.read(apiServiceProvider).fetchQualification(id);
});

/// Admin view: includes unpublished qualifications.
final adminQualificationsProvider = FutureProvider<List<Qualification>>((ref) {
  return ref.read(apiServiceProvider).fetchAdminQualifications();
});
