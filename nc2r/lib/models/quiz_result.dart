class QuizResult {
  final int score;
  final bool passed;
  final bool nextLessonUnlocked;
  final bool courseCompleted;
  final String? certificateUrl;

  const QuizResult({
    required this.score,
    required this.passed,
    required this.nextLessonUnlocked,
    required this.courseCompleted,
    required this.certificateUrl,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: json['score'] as int,
      passed: json['passed'] as bool,
      nextLessonUnlocked: json['next_lesson_unlocked'] as bool,
      courseCompleted: json['course_completed'] as bool,
      certificateUrl: json['certificate_url'] as String?,
    );
  }
}
