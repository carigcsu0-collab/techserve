import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exam.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import '../widgets/app_page_route.dart';
import '../widgets/motion.dart';
import '../widgets/question_page.dart';
import 'certificate_screen.dart';

/// Pre-test or post-test for a qualification. Questions arrive already
/// shuffled from the server.
class ExamScreen extends ConsumerStatefulWidget {
  final int qualificationId;
  final String type; // 'pre' | 'post'

  const ExamScreen({
    super.key,
    required this.qualificationId,
    required this.type,
  });

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  final _pageController = PageController();
  final Map<int, String> _answers = {};
  late Future<ExamPaper> _paper;
  int _page = 0;
  bool _submitting = false;

  String get _label => widget.type == 'pre' ? 'Pre-Test' : 'Post-Test';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _paper = ref
        .read(apiServiceProvider)
        .fetchExam(widget.qualificationId, widget.type);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submit(ExamPaper paper) async {
    setState(() => _submitting = true);
    try {
      final result =
          await ref.read(apiServiceProvider).submitExam(paper.id, _answers);
      if (!mounted) return;
      ref.invalidate(qualificationDetailProvider(widget.qualificationId));
      ref.invalidate(qualificationsProvider);
      ref.read(lessonProvider.notifier).refresh();
      if (result.certificateUrl != null) {
        ref.read(authProvider.notifier).setCertificate(result.certificateUrl!);
      }
      setState(() => _submitting = false);
      _showResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _showResult(ExamResult result) {
    final isPre = result.type == 'pre';
    final earnedCertificate =
        !isPre && result.passed && result.certificateUrl != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: PopIn(
          child: Icon(
            result.passed ? Icons.check_circle : Icons.info,
            size: 48,
            color: result.passed ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(isPre
            ? 'Pre-Test complete'
            : (result.passed ? 'You passed!' : 'Not quite')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountUpText(
              value: result.score,
              prefix: 'Score: ',
              suffix: '%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${result.correct} of ${result.total} correct'),
            const SizedBox(height: 8),
            Text(
              isPre
                  ? 'Your lessons are now unlocked. Good luck!'
                  : result.passed
                      ? 'Congratulations — you completed the course!'
                      : 'Review the lessons and try the post-test again.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (earnedCertificate) {
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
            child: Text(earnedCertificate ? 'View Certificate' : 'Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_label)),
      body: FutureBuilder<ExamPaper>(
        future: _paper,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friendlyError(snapshot.error!),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return _buildPaper(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildPaper(ExamPaper paper) {
    final total = paper.questions.length;
    final isLast = _page >= total - 1;

    return Column(
      children: [
        AnimatedLinearProgress(value: total == 0 ? 0 : (_page + 1) / total),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final question = paper.questions[index];
              return QuestionPage(
                question: question,
                index: index,
                total: total,
                value: _answers[question.id],
                onChanged: (v) => setState(() => _answers[question.id] = v),
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
                    '${_answers.length} of $total answered',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          if (!isLast) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          } else if (_answers.length == total) {
                            _submit(paper);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please answer all questions before submitting.',
                                ),
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
                      : Text(isLast ? 'Submit' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
