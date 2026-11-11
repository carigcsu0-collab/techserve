import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz.dart';
import '../models/quiz_result.dart';
import '../models/quiz_submission.dart';
import 'api_provider.dart';
import 'auth_provider.dart';
import 'lesson_provider.dart';

/// Fetches the quiz (questions, no correct answers) for a lesson.
/// autoDispose so a re-entry always gets a fresh copy.
final quizProvider = FutureProvider.autoDispose.family<Quiz, int>(
  (ref, lessonId) => ref.read(apiServiceProvider).fetchQuiz(lessonId),
);

/// Admin-only: learner submissions for a quiz, with per-answer grading.
final quizSubmissionsProvider =
    FutureProvider.autoDispose.family<List<QuizSubmission>, int>(
  (ref, quizId) => ref.read(apiServiceProvider).quizSubmissions(quizId),
);

/// Handles quiz submission. On a pass it updates lesson progress
/// (instant unlock) and stores the certificate on the user when the
/// whole course is finished.
class QuizSubmitNotifier extends AsyncNotifier<QuizResult?> {
  @override
  Future<QuizResult?> build() async => null;

  Future<QuizResult?> submit(
      int lessonId, int quizId, Map<int, String> answers) async {
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).submitQuiz(quizId, answers),
    );
    state = result;

    final value = result.valueOrNull;
    if (value != null && value.passed) {
      ref.read(lessonProvider.notifier).applyQuizPass(lessonId);
      // Background refresh for the authoritative list; a transient failure
      // here (e.g. a dropped connection) must not clobber the optimistic
      // unlock we just applied — see LessonNotifier.refresh().
      unawaited(ref.read(lessonProvider.notifier).refresh());

      if (value.courseCompleted && value.certificateUrl != null) {
        ref.read(authProvider.notifier).setCertificate(value.certificateUrl!);
      }
    }

    return value;
  }

  void reset() => state = const AsyncValue.data(null);
}

final quizSubmitProvider =
    AsyncNotifierProvider<QuizSubmitNotifier, QuizResult?>(QuizSubmitNotifier.new);
