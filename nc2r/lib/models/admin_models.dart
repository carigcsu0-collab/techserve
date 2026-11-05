class DashboardStats {
  final int users;
  final int admins;
  final int lessons;
  final int publishedLessons;
  final int draftLessons;
  final int quizSubmissions;
  final int passRate;
  final double averageScore;

  const DashboardStats({
    required this.users,
    required this.admins,
    required this.lessons,
    required this.publishedLessons,
    required this.draftLessons,
    required this.quizSubmissions,
    required this.passRate,
    required this.averageScore,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      users: json['users'] as int? ?? 0,
      admins: json['admins'] as int? ?? 0,
      lessons: json['lessons'] as int? ?? 0,
      publishedLessons: json['published_lessons'] as int? ?? 0,
      draftLessons: json['draft_lessons'] as int? ?? 0,
      quizSubmissions: json['quiz_submissions'] as int? ?? 0,
      passRate: json['pass_rate'] as int? ?? 0,
      averageScore: ((json['average_score'] as num?) ?? 0).toDouble(),
    );
  }
}

class AuditEntry {
  final int id;
  final String action;
  final String description;
  final String? adminName;
  final DateTime? createdAt;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.description,
    this.adminName,
    this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;
    return AuditEntry(
      id: json['id'] as int,
      action: json['action'] as String,
      description: (json['summary'] as String?) ?? (json['description'] as String?) ?? '',
      adminName: admin?['name'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

class ManagedUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final bool emailVerified;
  final DateTime? createdAt;

  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.emailVerified,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      emailVerified: (json['email_verified'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }

  ManagedUser copyWith({String? role}) => ManagedUser(
        id: id,
        name: name,
        email: email,
        role: role ?? this.role,
        emailVerified: emailVerified,
        createdAt: createdAt,
      );
}

class UserDetail {
  final ManagedUser user;
  final int totalLessons;
  final int completedCount;
  final List<String> completedTitles;
  final List<QuizAttempt> attempts;

  const UserDetail({
    required this.user,
    required this.totalLessons,
    required this.completedCount,
    required this.completedTitles,
    required this.attempts,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>;
    return UserDetail(
      user: ManagedUser.fromJson(json['user'] as Map<String, dynamic>),
      totalLessons: progress['total_lessons'] as int? ?? 0,
      completedCount: progress['completed_count'] as int? ?? 0,
      completedTitles: (progress['completed_lessons'] as List<dynamic>)
          .map((l) => (l as Map<String, dynamic>)['title'] as String)
          .toList(),
      attempts: (json['quiz_submissions'] as List<dynamic>)
          .map((s) => QuizAttempt.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizAttempt {
  final String lessonTitle;
  final int score;
  final bool passed;
  final DateTime? createdAt;

  const QuizAttempt({
    required this.lessonTitle,
    required this.score,
    required this.passed,
    this.createdAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      lessonTitle: (json['lesson_title'] as String?) ?? 'Unknown lesson',
      score: json['score'] as int? ?? 0,
      passed: json['passed'] as bool? ?? false,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}
