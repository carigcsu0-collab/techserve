class Qualification {
  final int id;
  final String title;
  final String description;
  final int orderIndex;
  final int lessonCount;
  final int completedCount;
  final double progress; // 0 to 1, learner view only
  final bool isCompleted;

  const Qualification({
    required this.id,
    required this.title,
    required this.description,
    this.orderIndex = 1,
    this.lessonCount = 0,
    this.completedCount = 0,
    this.progress = 0,
    this.isCompleted = false,
  });

  bool get isStarted => completedCount > 0 && !isCompleted;

  factory Qualification.fromJson(Map<String, dynamic> json) {
    return Qualification(
      id: json['id'] as int,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      orderIndex: (json['order_index'] as int?) ?? 1,
      lessonCount: (json['lesson_count'] as int?) ?? 0,
      completedCount: (json['completed_count'] as int?) ?? 0,
      progress: ((json['progress'] as num?) ?? 0).toDouble(),
      isCompleted: (json['is_completed'] as bool?) ?? false,
    );
  }
}
