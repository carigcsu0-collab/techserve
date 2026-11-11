import 'question.dart';

class ExamStatus {
  final int id;
  final int items;
  final int passingScore;
  final bool taken;
  final bool passed;
  final int? bestScore;
  final bool available; // post-test only: all lessons finished

  const ExamStatus({
    required this.id,
    required this.items,
    required this.passingScore,
    required this.taken,
    required this.passed,
    this.bestScore,
    this.available = true,
  });

  static ExamStatus? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return ExamStatus(
      id: json['id'] as int,
      items: (json['items'] as int?) ?? 0,
      passingScore: (json['passing_score'] as int?) ?? 0,
      taken: (json['taken'] as bool?) ?? false,
      passed: (json['passed'] as bool?) ?? false,
      bestScore: (json['best_score'] as num?)?.toInt(),
      available: (json['available'] as bool?) ?? true,
    );
  }
}

class ExamStatuses {
  final ExamStatus? pre;
  final ExamStatus? post;

  const ExamStatuses({this.pre, this.post});

  factory ExamStatuses.fromJson(Map<String, dynamic>? json) => ExamStatuses(
        pre: ExamStatus.fromJsonOrNull(json?['pre']),
        post: ExamStatus.fromJsonOrNull(json?['post']),
      );
}

/// A shuffled set of questions served to a learner.
class ExamPaper {
  final int id;
  final String type; // 'pre' | 'post'
  final int passingScore;
  final List<Question> questions;

  const ExamPaper({
    required this.id,
    required this.type,
    required this.passingScore,
    required this.questions,
  });

  bool get isPre => type == 'pre';

  factory ExamPaper.fromJson(Map<String, dynamic> json) => ExamPaper(
        id: json['id'] as int,
        type: json['type'] as String,
        passingScore: json['passing_score'] as int,
        questions: (json['questions'] as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class ExamResult {
  final int score;
  final int correct;
  final int total;
  final bool passed;
  final String type;
  final String? certificateUrl;

  const ExamResult({
    required this.score,
    required this.correct,
    required this.total,
    required this.passed,
    required this.type,
    this.certificateUrl,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
        score: json['score'] as int,
        correct: json['correct'] as int,
        total: json['total'] as int,
        passed: json['passed'] as bool,
        type: json['type'] as String,
        certificateUrl: json['certificate_url'] as String?,
      );
}

/// Admin view of an exam, including the whole question bank and answers.
class AdminExam {
  final int id;
  final String type;
  final int passingScore;
  final int? questionCount;
  final List<Question> questions;

  const AdminExam({
    required this.id,
    required this.type,
    required this.passingScore,
    required this.questionCount,
    required this.questions,
  });

  factory AdminExam.fromJson(Map<String, dynamic> json) => AdminExam(
        id: json['id'] as int,
        type: json['type'] as String,
        passingScore: json['passing_score'] as int,
        questionCount: json['question_count'] as int?,
        questions: (json['questions'] as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}
