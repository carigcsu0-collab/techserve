import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/admin_models.dart';
import '../models/app_user.dart';
import '../models/lesson.dart';
import '../models/qualification.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';
import '../models/quiz_submission.dart';

/// Wraps a failed request with its HTTP status code (when available) so
/// callers can distinguish e.g. a 404 ("not found yet") from a real
/// failure (timeout, 500, auth) instead of treating every error the same.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Machine-readable reason from the API (e.g. `email_unverified`).
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiService {
  /// Android emulators reach the host machine's localhost via 10.0.2.2;
  /// desktop/web targets use localhost directly.
  /// Override at launch: flutter run --dart-define=API_URL=http://192.168.x.x:8000/api
  static String get baseUrl {
    const defined = String.fromEnvironment('API_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return 'http://localhost:8000/api';
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000/api'
        : 'http://localhost:8000/api';
  }

  final Dio _dio;

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Accept': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  void setToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ---- Auth ----

  Future<({AppUser user, String token})> login(
    String email,
    String password,
  ) async {
    final data = await _post('/login', {'email': email, 'password': password});
    return _authPayload(data);
  }

  /// Returns null when the account must confirm its email code first.
  Future<({AppUser user, String token})?> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    final data = await _post('/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    if (data['verification_required'] == true) return null;
    return _authPayload(data);
  }

  Future<({AppUser user, String token})> verifyEmail(
    String email,
    String code,
  ) async {
    final data = await _post('/verify-email', {'email': email, 'code': code});
    return _authPayload(data);
  }

  Future<void> resendVerification(String email) async {
    await _post('/resend-verification', {'email': email});
  }

  Future<void> logout() async {
    await _post('/logout', {});
    setToken(null);
  }

  Future<({AppUser user, String token})> loginWithGoogle(
    String idToken,
  ) async => _authPayload(await _post('/auth/google', {'id_token': idToken}));

  Future<({AppUser user, String token})> loginWithFacebook(
    String accessToken,
  ) async => _authPayload(
    await _post('/auth/facebook', {'access_token': accessToken}),
  );

  ({AppUser user, String token}) _authPayload(Map<String, dynamic> data) {
    return (
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  /// Fetch the authenticated user (used to restore a session on launch).
  Future<AppUser> fetchUser() async {
    final data = await _get('/user');
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateProfile(String name) async {
    final data = await _put('/user/profile', {'name': name});
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _put('/user/password', {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  // ---- Lessons ----

  Future<List<Lesson>> fetchLessons() async {
    final data = await _get('/lessons');
    return (data['lessons'] as List<dynamic>)
        .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  // ---- Qualifications ----

  Future<List<Qualification>> fetchQualifications() async {
    final data = await _get('/qualifications');
    return (data['qualifications'] as List<dynamic>)
        .map((q) => Qualification.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  /// Returns the qualification plus its lessons, with lock state for the current user.
  Future<({Qualification qualification, List<Lesson> lessons})>
      fetchQualification(int id) async {
    final data = await _get('/qualifications/$id');
    return (
      qualification:
          Qualification.fromJson(data['qualification'] as Map<String, dynamic>),
      lessons: (data['lessons'] as List<dynamic>)
          .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  // ---- Quizzes ----

  Future<Quiz> fetchQuiz(int lessonId) async {
    final data = await _get('/lessons/$lessonId/quiz');
    return Quiz.fromJson(data['quiz'] as Map<String, dynamic>);
  }

  /// [answers] maps question id -> selected/entered answer.
  Future<QuizResult> submitQuiz(int quizId, Map<int, String> answers) async {
    final data = await _post('/quizzes/$quizId/submit', {
      'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
    });
    return QuizResult.fromJson(data);
  }

  // ---- Admin: lessons ----

  /// [onUploadProgress] receives bytes sent so far and the total, for file uploads.
  Future<Lesson> createLesson({
    required String title,
    required String description,
    required String mediaType,
    required int orderIndex,
    int? qualificationId,
    String? mediaUrl,
    String? mediaFilePath,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    final data = await _sendForm('POST', '/admin/lessons', {
      'title': title,
      'description': description,
      'media_type': mediaType,
      'order_index': '$orderIndex',
      if (qualificationId != null) 'qualification_id': '$qualificationId',
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
      if (mediaFilePath != null)
        'media_file': await MultipartFile.fromFile(mediaFilePath),
    }, onUploadProgress: onUploadProgress);
    return Lesson.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  /// Pass [clearQualification] to move the lesson out of its qualification.
  Future<Lesson> updateLesson(
    int id, {
    String? title,
    String? description,
    String? mediaType,
    int? orderIndex,
    int? qualificationId,
    bool clearQualification = false,
    String? mediaUrl,
    String? mediaFilePath,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    // Multipart PUT isn't parsed by PHP — Laravel method-spoofs via _method.
    final data = await _sendForm('POST', '/admin/lessons/$id', {
      '_method': 'PUT',
      'title': ?title,
      'description': ?description,
      'media_type': ?mediaType,
      if (orderIndex != null) 'order_index': '$orderIndex',
      if (clearQualification)
        'qualification_id': ''
      else if (qualificationId != null)
        'qualification_id': '$qualificationId',
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
      if (mediaFilePath != null)
        'media_file': await MultipartFile.fromFile(mediaFilePath),
    }, onUploadProgress: onUploadProgress);
    return Lesson.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<void> deleteLesson(int id) async {
    await _delete('/admin/lessons/$id');
  }

  // ---- Admin: quizzes ----

  Future<Quiz> upsertQuiz(int lessonId, int passingScore) async {
    final data = await _post('/admin/lessons/$lessonId/quiz', {
      'passing_score': '$passingScore',
    });
    return Quiz.fromJson(data['quiz'] as Map<String, dynamic>);
  }

  Future<Quiz> updateQuiz(int quizId, int passingScore) async {
    final data = await _put('/admin/quizzes/$quizId', {
      'passing_score': '$passingScore',
    });
    return Quiz.fromJson(data['quiz'] as Map<String, dynamic>);
  }

  Future<void> deleteQuiz(int quizId) async {
    await _delete('/admin/quizzes/$quizId');
  }

  Future<List<QuizSubmission>> quizSubmissions(int quizId) async {
    final data = await _get('/admin/quizzes/$quizId/submissions');
    return (data['submissions'] as List<dynamic>)
        .map((s) => QuizSubmission.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteQuizSubmission(int quizId, int submissionId) async {
    await _delete('/admin/quizzes/$quizId/submissions/$submissionId');
  }

  // ---- Admin: dashboard, activity, users ----

  Future<({DashboardStats stats, List<AuditEntry> recent})>
      fetchDashboard() async {
    final data = await _get('/admin/dashboard');
    return (
      stats: DashboardStats.fromJson(data['stats'] as Map<String, dynamic>),
      recent: (data['recent_activity'] as List<dynamic>)
          .map((l) => AuditEntry.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<AuditEntry>> fetchAuditLogs() async {
    final data = await _get('/admin/audit-logs');
    return (data['logs'] as List<dynamic>)
        .map((l) => AuditEntry.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<List<ManagedUser>> fetchUsers({String query = ''}) async {
    final data = await _get(
      '/admin/users${query.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(query)}'}',
    );
    return (data['users'] as List<dynamic>)
        .map((u) => ManagedUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<UserDetail> fetchUserDetail(int id) async {
    final data = await _get('/admin/users/$id');
    return UserDetail.fromJson(data);
  }

  Future<ManagedUser> updateUserRole(int id, String role) async {
    final data = await _put('/admin/users/$id/role', {'role': role});
    return ManagedUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ManagedUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await _post('/admin/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    return ManagedUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ManagedUser> updateUser(
    int id, {
    required String name,
    required String email,
    required String role,
    String? password,
  }) async {
    final data = await _put('/admin/users/$id', {
      'name': name,
      'email': email,
      'role': role,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return ManagedUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(int id) async {
    await _delete('/admin/users/$id');
  }

  // ---- Admin: qualifications ----

  Future<List<Qualification>> fetchAdminQualifications() async {
    final data = await _get('/admin/qualifications');
    return (data['qualifications'] as List<dynamic>)
        .map((q) => Qualification.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  Future<Qualification> createQualification({
    required String title,
    required String description,
  }) async {
    final data = await _post('/admin/qualifications', {
      'title': title,
      'description': description,
    });
    return Qualification.fromJson(data['qualification'] as Map<String, dynamic>);
  }

  Future<Qualification> updateQualification(
    int id, {
    String? title,
    String? description,
  }) async {
    final data = await _put('/admin/qualifications/$id', {
      'title': ?title,
      'description': ?description,
    });
    return Qualification.fromJson(data['qualification'] as Map<String, dynamic>);
  }

  Future<void> deleteQualification(int id) async {
    await _delete('/admin/qualifications/$id');
  }

  Future<void> reorderQualifications(List<int> ids) async {
    await _put('/admin/qualifications/reorder', {'ids': ids});
  }

  // ---- Admin: lesson ordering ----

  /// [ids] must list every lesson in [qualificationId] (null = unassigned) exactly once.
  Future<void> reorderLessons(int? qualificationId, List<int> ids) async {
    await _put('/admin/lessons/reorder', {
      'qualification_id': qualificationId,
      'ids': ids,
    });
  }

  // ---- Admin: questions ----

  Future<Question> createQuestion(
    int quizId, {
    required String questionText,
    required String questionType,
    List<String>? options,
    required String correctAnswer,
  }) async {
    final data = await _post('/admin/quizzes/$quizId/questions', {
      'question_text': questionText,
      'question_type': questionType,
      'options': options,
      'correct_answer': correctAnswer,
    });
    return Question.fromJson(data['question'] as Map<String, dynamic>);
  }

  Future<Question> updateQuestion(
    int id, {
    required String questionText,
    required String questionType,
    List<String>? options,
    required String correctAnswer,
  }) async {
    final data = await _put('/admin/questions/$id', {
      'question_text': questionText,
      'question_type': questionType,
      'options': options,
      'correct_answer': correctAnswer,
    });
    return Question.fromJson(data['question'] as Map<String, dynamic>);
  }

  Future<void> deleteQuestion(int id) async {
    await _delete('/admin/questions/$id');
  }

  // ---- HTTP helpers ----

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(path, data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        _message(e),
        statusCode: e.response?.statusCode,
        code: _code(e),
      );
    }
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put(path, data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await _dio.delete(path);
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _sendForm(
    String method,
    String path,
    Map<String, dynamic> fields, {
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: FormData.fromMap(fields),
        // Big uploads are stored on the server before it replies, so allow a longer wait.
        options: Options(
          method: method,
          receiveTimeout: onUploadProgress != null
              ? const Duration(minutes: 10)
              : null,
        ),
        onSendProgress: onUploadProgress,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw ApiException(
          'The server sent an unexpected reply (HTTP ${response.statusCode}). Please try again.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  String? _code(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['code'] is String) {
      return data['code'] as String;
    }
    return null;
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout =>
        'Connection timed out. Is the API server running?',
      DioExceptionType.connectionError =>
        'Cannot reach the server. Check your connection and API_URL.',
      _ => 'Request failed (${e.response?.statusCode ?? 'no response'})',
    };
  }
}
