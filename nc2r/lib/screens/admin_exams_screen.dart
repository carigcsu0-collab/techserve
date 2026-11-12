import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exam.dart';
import '../models/question.dart';
import '../providers/api_provider.dart';
import '../services/error_messages.dart';
import '../services/question_import.dart';
import '../widgets/question_editor_dialog.dart';

/// Admin: manage the pre-test and post-test question banks of a qualification.
class AdminExamsScreen extends ConsumerStatefulWidget {
  final int qualificationId;
  final String title;

  const AdminExamsScreen(
      {super.key, required this.qualificationId, required this.title});

  @override
  ConsumerState<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends ConsumerState<AdminExamsScreen> {
  late Future<({AdminExam pre, AdminExam post})> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<({AdminExam pre, AdminExam post})> _fetch() =>
      ref.read(apiServiceProvider).fetchAdminExams(widget.qualificationId);

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.title} — Tests'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Pre-Test'), Tab(text: 'Post-Test')],
          ),
        ),
        body: FutureBuilder(
          future: _future,
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
                        onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final exams = snapshot.data!;
            return TabBarView(
              children: [
                _ExamEditor(
                    key: ValueKey('pre-${exams.pre.questions.length}'),
                    exam: exams.pre,
                    onChanged: _reload),
                _ExamEditor(
                    key: ValueKey('post-${exams.post.questions.length}'),
                    exam: exams.post,
                    onChanged: _reload),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExamEditor extends ConsumerStatefulWidget {
  final AdminExam exam;
  final VoidCallback onChanged;

  const _ExamEditor({super.key, required this.exam, required this.onChanged});

  @override
  ConsumerState<_ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends ConsumerState<_ExamEditor> {
  late final TextEditingController _count;
  late final TextEditingController _passing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _count = TextEditingController(
        text: widget.exam.questionCount?.toString() ?? '');
    _passing = TextEditingController(text: '${widget.exam.passingScore}');
  }

  @override
  void dispose() {
    _count.dispose();
    _passing.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  Future<void> _saveSettings() async {
    final passing = int.tryParse(_passing.text.trim());
    final countText = _count.text.trim();
    final count = countText.isEmpty ? null : int.tryParse(countText);
    if (passing == null || passing < 1 || passing > 100) {
      _showError(Exception('Passing score must be 1–100'));
      return;
    }
    if (countText.isNotEmpty && (count == null || count < 1)) {
      _showError(Exception('Items per exam must be 1 or more'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(apiServiceProvider)
          .updateExam(widget.exam.id, passingScore: passing, questionCount: count);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editQuestion({Question? question}) async {
    final draft = await showDialog<QuestionDraft>(
      context: context,
      builder: (_) => QuestionEditorDialog(question: question),
    );
    if (draft == null) return;
    try {
      final api = ref.read(apiServiceProvider);
      if (question == null) {
        await api.createExamQuestion(
          widget.exam.id,
          questionText: draft.questionText,
          questionType: draft.questionType,
          options: draft.options ?? const [],
          correctAnswer: draft.correctAnswer,
        );
      } else {
        await api.updateExamQuestion(
          question.id,
          questionText: draft.questionText,
          questionType: draft.questionType,
          options: draft.options ?? const [],
          correctAnswer: draft.correctAnswer,
        );
      }
      widget.onChanged();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Question question) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(question.questionText,
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).deleteExamQuestion(question.id);
      widget.onChanged();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _import() async {
    final parsed = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (parsed == null || parsed.isEmpty) return;
    try {
      await ref
          .read(apiServiceProvider)
          .bulkCreateExamQuestions(widget.exam.id, parsed);
      widget.onChanged();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.exam.questions;
    final bank = questions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$bank question(s) in the bank',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Each learner gets the number of items below, picked at '
                  'random from the bank, in shuffled order. Leave blank to '
                  'use every question. Learners only see this test once it '
                  'has at least one question.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Items per exam',
                          hintText: 'All',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Passing score %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveSettings,
                    child: const Text('Save settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
                onPressed: () => _editQuestion(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: const Text('Import many'),
                onPressed: _import,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < questions.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(questions[i].questionText,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('Answer: ${questions[i].correctAnswer ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _editQuestion(question: questions[i]),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(questions[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paste-in format: questions separated by a blank line. First line is the
/// question, each following line an option; prefix the correct one with `*`.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final mobile = Platform.isAndroid || Platform.isIOS;
    final picked = await FilePicker.pickFile(
      type: mobile ? FileType.any : FileType.custom,
      allowedExtensions: mobile ? null : const ['txt', 'csv'],
    );
    final path = picked?.path;
    if (path == null) return;
    try {
      _text.text = await File(path).readAsString();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read that file.');
    }
  }

  void _parse() {
    try {
      Navigator.of(context).pop(parseQuestionImport(_text.text));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import questions'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste text or load a .txt / .csv file.\n\n'
              'Text: one question per block, blocks separated by a blank line.\n'
              '  Multiple choice: question, then options; put * before the correct one.\n'
              '  True/false: start with TF: and add an Answer: True or Answer: False line.\n'
              '  Identification: start with ID: and add an Answer: line.\n\n'
              'CSV (question bank): Question,Option A,Option B,Option C,Option D,Correct Answer.\n'
              'CSV (typed): type,question,options,answer with options separated by |.\n'
              'Type: multiple_choice, true_false or identification.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Load from .txt file'),
              onPressed: _loadFile,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 12,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _parse, child: const Text('Import')),
      ],
    );
  }
}
