import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/question.dart';
import '../providers/api_provider.dart';
import '../providers/quiz_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_page_route.dart';
import '../widgets/question_editor_dialog.dart';
import 'admin_submissions_screen.dart';

class AdminQuizScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const AdminQuizScreen({super.key, required this.lesson});

  @override
  ConsumerState<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends ConsumerState<AdminQuizScreen> {
  late final TextEditingController _passingScore;
  bool _savingScore = false;

  @override
  void initState() {
    super.initState();
    _passingScore = TextEditingController();
  }

  @override
  void dispose() {
    _passingScore.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(quizProvider(widget.lesson.id));
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _saveScore(int? quizId) async {
    final score = int.tryParse(_passingScore.text.trim());
    if (score == null || score < 1 || score > 100) {
      _showError(Exception('Passing score must be 1–100'));
      return;
    }
    setState(() => _savingScore = true);
    try {
      final api = ref.read(apiServiceProvider);
      if (quizId == null) {
        await api.upsertQuiz(widget.lesson.id, score);
      } else {
        await api.updateQuiz(quizId, score);
      }
      _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _savingScore = false);
    }
  }

  Future<void> _editQuestion(int quizId, {Question? question}) async {
    final draft = await showDialog<QuestionDraft>(
      context: context,
      builder: (_) => QuestionEditorDialog(question: question),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      if (question == null) {
        await api.createQuestion(
          quizId,
          questionText: draft.questionText,
          questionType: draft.questionType,
          options: draft.options,
          correctAnswer: draft.correctAnswer,
        );
      } else {
        await api.updateQuestion(
          question.id,
          questionText: draft.questionText,
          questionType: draft.questionType,
          options: draft.options,
          correctAnswer: draft.correctAnswer,
        );
      }
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(question.questionText,
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiServiceProvider).deleteQuestion(question.id);
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  String _typeLabel(Question q) => switch (q.type) {
        QuestionType.multipleChoice => 'Multiple choice',
        QuestionType.trueFalse => 'True / False',
        QuestionType.identification => 'Identification',
      };

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizProvider(widget.lesson.id));

    final quiz = quizAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz — ${widget.lesson.title}'),
        actions: [
          if (quiz != null)
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'View submissions',
              onPressed: () => Navigator.of(context).push(
                SlidePageRoute(
                  builder: (_) => AdminSubmissionsScreen(
                    lesson: widget.lesson,
                    quiz: quiz,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => error is ApiException && error.isNotFound
            ? _buildNoQuiz() // no quiz created for this lesson yet
            : _buildError(error),
        data: (quiz) {
          if (_passingScore.text.isEmpty) {
            _passingScore.text = '${quiz.passingScore}';
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _passingScore,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Passing score (%)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _savingScore ? null : () => _saveScore(quiz.id),
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Questions (${quiz.questions.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    onPressed: () => _editQuestion(quiz.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < quiz.questions.length; i++)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(quiz.questions[i].questionText),
                    subtitle: Text(
                      '${_typeLabel(quiz.questions[i])} • Answer: ${quiz.questions[i].correctAnswer ?? '—'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: false,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editQuestion(quiz.id,
                              question: quiz.questions[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _deleteQuestion(quiz.questions[i]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildNoQuiz() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This lesson has no quiz yet.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passingScore,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Passing score (%)',
                hintText: '70',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _savingScore ? null : () => _saveScore(null),
              child: const Text('Create Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
