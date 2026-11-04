class SubmissionAnswer {
  final int questionId;
  final String questionText;
  final String questionType;
  final List<String>? options;
  final String? submittedAnswer;
  final String correctAnswer;
  final bool isCorrect;

  const SubmissionAnswer({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    this.options,
    this.submittedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
  });

  factory SubmissionAnswer.fromJson(Map<String, dynamic> json) {
    return SubmissionAnswer(
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String,
      options: (json['options'] as List<dynamic>?)
          ?.map((o) => o as String)
          .toList(),
      submittedAnswer: json['submitted_answer'] as String?,
      correctAnswer: json['correct_answer'] as String,
      isCorrect: json['is_correct'] as bool,
    );
  }
}

class QuizSubmission {
  final int id;
  final String userName;
  final String userEmail;
  final int score;
  final bool passed;
  final DateTime? createdAt;
  final List<SubmissionAnswer> answers;

  const QuizSubmission({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.score,
    required this.passed,
    this.createdAt,
    required this.answers,
  });

  factory QuizSubmission.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return QuizSubmission(
      id: json['id'] as int,
      userName: user?['name'] as String? ?? 'Unknown',
      userEmail: user?['email'] as String? ?? '',
      score: json['score'] as int,
      passed: json['passed'] as bool,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      answers: (json['answers'] as List<dynamic>)
          .map((a) => SubmissionAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}
