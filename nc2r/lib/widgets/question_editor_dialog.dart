import 'package:flutter/material.dart';

import '../models/question.dart';

/// Result of the question editor — consumed by the caller to call the API.
class QuestionDraft {
  final String questionText;
  final String questionType; // API enum string
  final List<String>? options;
  final String correctAnswer;

  const QuestionDraft({
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswer,
  });
}

/// Editor for creating/updating a quiz question. Returns a [QuestionDraft]
/// via Navigator pop, or null when cancelled.
class QuestionEditorDialog extends StatefulWidget {
  final Question? question; // null = create

  const QuestionEditorDialog({super.key, this.question});

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionText;
  late final TextEditingController _identAnswer;
  QuestionType _type = QuestionType.multipleChoice;

  // Multiple choice state
  List<TextEditingController> _optionCtrls = [];
  String? _correctOption;

  // True/false state
  String _tfAnswer = 'True';

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionText = TextEditingController(text: q?.questionText ?? '');
    _identAnswer = TextEditingController(
        text: q != null && q.type == QuestionType.identification
            ? q.correctAnswer
            : '');
    if (q != null) {
      _type = q.type;
      if (q.type == QuestionType.multipleChoice) {
        _optionCtrls =
            q.options.map((o) => TextEditingController(text: o)).toList();
        _correctOption =
            q.options.contains(q.correctAnswer) ? q.correctAnswer : null;
      } else if (q.type == QuestionType.trueFalse) {
        _tfAnswer = q.correctAnswer ?? 'True';
      }
    }
    if (_optionCtrls.isEmpty) {
      _optionCtrls = List.generate(3, (_) => TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionText.dispose();
    _identAnswer.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchType(QuestionType t) {
    setState(() => _type = t);
  }

  List<String> get _options =>
      _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    switch (_type) {
      case QuestionType.multipleChoice:
        if (_options.length < 2) {
          _toast('Add at least 2 options');
          return;
        }
        if (_correctOption == null || !_options.contains(_correctOption)) {
          _toast('Pick the correct answer');
          return;
        }
        Navigator.of(context).pop(QuestionDraft(
          questionText: _questionText.text.trim(),
          questionType: 'multiple_choice',
          options: _options,
          correctAnswer: _correctOption!,
        ));
      case QuestionType.trueFalse:
        Navigator.of(context).pop(QuestionDraft(
          questionText: _questionText.text.trim(),
          questionType: 'true_false',
          options: const ['True', 'False'],
          correctAnswer: _tfAnswer,
        ));
      case QuestionType.identification:
        Navigator.of(context).pop(QuestionDraft(
          questionText: _questionText.text.trim(),
          questionType: 'identification',
          options: null,
          correctAnswer: _identAnswer.text.trim(),
        ));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'New Question' : 'Edit Question'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _questionText,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Question', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<QuestionType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                      labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: QuestionType.multipleChoice,
                        child: Text('Multiple choice')),
                    DropdownMenuItem(
                        value: QuestionType.trueFalse,
                        child: Text('True / False')),
                    DropdownMenuItem(
                        value: QuestionType.identification,
                        child: Text('Identification')),
                  ],
                  onChanged: (v) => _switchType(v!),
                ),
                const SizedBox(height: 12),
                switch (_type) {
                  QuestionType.multipleChoice => _buildMcEditor(),
                  QuestionType.trueFalse => _buildTfEditor(),
                  QuestionType.identification => _buildIdEditor(),
                },
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  Widget _buildMcEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _optionCtrls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _optionCtrls[i],
                    decoration: InputDecoration(
                      labelText: 'Option ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove option',
                  onPressed: _optionCtrls.length > 2
                      ? () => setState(() {
                            final removed =
                                _optionCtrls.removeAt(i).text.trim();
                            if (_correctOption == removed) {
                              _correctOption = null;
                            }
                          })
                      : null,
                ),
              ],
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
          onPressed: () =>
              setState(() => _optionCtrls.add(TextEditingController())),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue:
              _options.contains(_correctOption) ? _correctOption : null,
          decoration: const InputDecoration(
              labelText: 'Correct answer', border: OutlineInputBorder()),
          items: _options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _correctOption = v),
        ),
      ],
    );
  }

  Widget _buildTfEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Correct answer', style: Theme.of(context).textTheme.labelLarge),
        RadioGroup<String>(
          groupValue: _tfAnswer,
          onChanged: (v) => setState(() => _tfAnswer = v!),
          child: const Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text('True'),
                  value: 'True',
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text('False'),
                  value: 'False',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdEditor() {
    return TextFormField(
      controller: _identAnswer,
      decoration: const InputDecoration(
        labelText: 'Correct answer',
        helperText: 'Graded case-insensitively',
        border: OutlineInputBorder(),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
