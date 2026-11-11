class Lesson {
  final int id;
  final String title;
  final String description;
  final String? mediaUrl; // null while the lesson is locked
  final String mediaType; // 'video' | 'image'
  final int orderIndex;
  final bool isUnlocked;
  final bool isCompleted;
  final int? qualificationId; // null = not assigned to a qualification
  final bool hasQuiz; // lesson has a quiz with questions

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaUrl,
    required this.mediaType,
    required this.orderIndex,
    required this.isUnlocked,
    required this.isCompleted,
    this.qualificationId,
    this.hasQuiz = false,
  });

  bool get isVideo => mediaType == 'video';

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String,
      orderIndex: json['order_index'] as int,
      // Admin create/update replies omit learner progress, so default these.
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
      qualificationId: json['qualification_id'] as int?,
      hasQuiz: json['has_quiz'] as bool? ?? false,
    );
  }

  Lesson copyWith({
    String? mediaUrl,
    bool? isUnlocked,
    bool? isCompleted,
  }) {
    return Lesson(
      id: id,
      title: title,
      description: description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType,
      orderIndex: orderIndex,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
      qualificationId: qualificationId,
      hasQuiz: hasQuiz,
    );
  }
}
