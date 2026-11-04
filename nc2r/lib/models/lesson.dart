class Lesson {
  final int id;
  final String title;
  final String description;
  final String? mediaUrl; // null while the lesson is locked
  final String mediaType; // 'video' | 'image'
  final int orderIndex;
  final bool isUnlocked;
  final bool isCompleted;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaUrl,
    required this.mediaType,
    required this.orderIndex,
    required this.isUnlocked,
    required this.isCompleted,
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
      isUnlocked: json['is_unlocked'] as bool,
      isCompleted: json['is_completed'] as bool,
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
    );
  }
}
