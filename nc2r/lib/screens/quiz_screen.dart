import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';
import '../providers/quiz_provider.dart';
import '../widgets/app_page_route.dart';
import '../widgets/question_page.dart';
import '../widgets/tap_scale.dart';
import 'certificate_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const QuizScreen({super.key, required this.lesson});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _pageController = PageController();
  final Map<int, String> _answers = {};
  // One controller per free-text question, created lazily and kept for the
  // life of this screen so PageView rebuilding/recycling a page never loses
  // what the user already typed (TextFormField.initialValue only applies
  // once, which is the bug this avoids).
  final Map<int, TextEditingController> _textControllers = {};
  int _page = 0;
  bool _submitting = false;

  TextEditingController _controllerFor(int questionId) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _answers[questionId]),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _allAnswered => _answers.values.every((a) => a.trim().isNotEmpty);

  Future<void> _submit(Quiz quiz) async {
    setState(() => _submitting = true);

    final result = await ref
        .read(quizSubmitProvider.notifier)
        .submit(widget.lesson.id, quiz.id, _answers);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      final error = ref.read(quizSubmitProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Submission failed')),
      );
      return;
    }

    _showResult(result);
  }

  void _showResult(QuizResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          result.passed ? Icons.check_circle : Icons.cancel,
          size: 48,
          color: result.passed ? Colors.green : Colors.red,
        ),
        title: Text(result.passed ? 'You passed!' : 'Not quite'),
        content: Text(
          result.courseCompleted
              ? 'Score: ${result.score}%\n\nCongratulations — you completed every lesson in the course!'
              : result.passed
                  ? 'Score: ${result.score}%\nThe next lesson is now unlocked.'
                  : 'Score: ${result.score}%\nReview the lesson and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (result.courseCompleted && result.certificateUrl != null) {
                Navigator.of(context).pushReplacement(
                  FadePageRoute(
                    builder: (_) => CertificateScreen(
                      certificateUrl: result.certificateUrl!,
                    ),
                  ),
                );
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(result.courseCompleted ? 'View Certificate' : 'Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizProvider(widget.lesson.id));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.lesson.title} — Quiz')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(quizProvider(widget.lesson.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (quiz) => Column(
          children: [
            LinearProgressIndicator(
              value: quiz.questions.isEmpty
                  ? 0
                  : (_page + 1) / quiz.questions.length,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quiz.questions.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final question = quiz.questions[index];
                  return QuestionPage(
                    question: question,
                    index: index,
                    total: quiz.questions.length,
                    value: _answers[question.id],
                    controller: question.isFreeText
                        ? _controllerFor(question.id)
                        : null,
                    onChanged: (v) =>
                        setState(() => _answers[question.id] = v),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (_page > 0)
                      TextButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        child: const Text('Back'),
                      ),
                    Expanded(
                      child: Text(
                        '${_answers.values.where((a) => a.trim().isNotEmpty).length} of ${quiz.questions.length} answered',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PressableScale(
                      child: FilledButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                if (_page < quiz.questions.length - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                } else if (_allAnswered &&
                                    _answers.length == quiz.questions.length) {
                                  _submit(quiz);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please answer all questions before submitting.'),
                                    ),
                                  );
                                }
                              },
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_page < quiz.questions.length - 1
                                ? 'Next'
                                : 'Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
