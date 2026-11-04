import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/quiz_submission.dart';
import '../providers/quiz_provider.dart';

/// Admin view of every learner's quiz attempt — shows each submitted
/// answer alongside the correct answer with correct/wrong marking.
class AdminSubmissionsScreen extends ConsumerWidget {
  final Lesson lesson;
  final Quiz quiz;

  const AdminSubmissionsScreen({
    super.key,
    required this.lesson,
    required this.quiz,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(quizSubmissionsProvider(quiz.id));

    return Scaffold(
      appBar: AppBar(title: Text('Activity — ${lesson.title}')),
      body: submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(quizSubmissionsProvider(quiz.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (submissions) => submissions.isEmpty
            ? const Center(child: Text('No submissions yet.'))
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(quizSubmissionsProvider(quiz.id)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: submissions.length,
                  itemBuilder: (context, i) =>
                      _SubmissionCard(submission: submissions[i]),
                ),
              ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final QuizSubmission submission;

  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final correct =
        submission.answers.where((a) => a.isCorrect).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: submission.passed
              ? Colors.green.shade100
              : scheme.errorContainer,
          child: Icon(
            submission.passed ? Icons.check : Icons.close,
            color: submission.passed
                ? Colors.green.shade800
                : scheme.onErrorContainer,
          ),
        ),
        title: Text(submission.userName),
        subtitle: Text(
          '${submission.userEmail} • $correct/${submission.answers.length} correct'
          '${submission.createdAt != null ? ' • ${_formatDate(submission.createdAt!)}' : ''}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: submission.passed
                ? Colors.green.shade50
                : scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${submission.score}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: submission.passed
                  ? Colors.green.shade800
                  : scheme.onErrorContainer,
            ),
          ),
        ),
        children: [
          const Divider(height: 1),
          for (var i = 0; i < submission.answers.length; i++)
            _AnswerTile(index: i + 1, answer: submission.answers[i]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _AnswerTile extends StatelessWidget {
  final int index;
  final SubmissionAnswer answer;

  const _AnswerTile({required this.index, required this.answer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final correctColor = Colors.green.shade800;

    return ListTile(
      dense: true,
      leading: Icon(
        answer.isCorrect ? Icons.check_circle : Icons.cancel,
        color: answer.isCorrect ? correctColor : scheme.error,
        size: 20,
      ),
      title: Text(
        '$index. ${answer.questionText}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Answered: ',
              children: [
                TextSpan(
                  text: answer.submittedAnswer?.isNotEmpty == true
                      ? answer.submittedAnswer!
                      : '(no answer)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: answer.isCorrect ? correctColor : scheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (!answer.isCorrect)
            Text(
              'Correct: ${answer.correctAnswer}',
              style: TextStyle(
                  color: correctColor, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
