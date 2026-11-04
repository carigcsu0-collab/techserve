import 'question.dart';

class Quiz {
  final int id;
  final int lessonId;
  final int passingScore;
  final List<Question> questions;

  const Quiz({
    required this.id,
    required this.lessonId,
    required this.passingScore,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as int,
      lessonId: json['lesson_id'] as int,
      passingScore: json['passing_score'] as int,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
