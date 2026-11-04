enum QuestionType { multipleChoice, trueFalse, identification }

class Question {
  final int id;
  final String questionText;
  final QuestionType type;
  final List<String> options; // empty for identification questions
  final String? correctAnswer; // only present in admin responses

  const Question({
    required this.id,
    required this.questionText,
    required this.type,
    required this.options,
    this.correctAnswer,
  });

  bool get isFreeText => type == QuestionType.identification;

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      questionText: json['question_text'] as String,
      type: _typeFrom(json['question_type'] as String?),
      correctAnswer: json['correct_answer'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o.toString())
              .toList() ??
          const [],
    );
  }

  static QuestionType _typeFrom(String? value) {
    return switch (value) {
      'true_false' => QuestionType.trueFalse,
      'identification' => QuestionType.identification,
      _ => QuestionType.multipleChoice,
    };
  }
}
