import 'package:flutter/material.dart';

import '../models/question.dart';
import 'tap_scale.dart';

/// One page of the quiz wizard. Renders options for choice questions or a
/// free-text field for identification questions.
class QuestionPage extends StatelessWidget {
  final Question question;
  final int index;
  final int total;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Owned by the parent quiz screen (one per question id, kept alive for
  /// the lifetime of the quiz) so free-text answers survive PageView
  /// rebuilding/recycling this page's widgets. Required when
  /// [Question.isFreeText] is true.
  final TextEditingController? controller;

  const QuestionPage({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.value,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${index + 1} of $total',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (question.isFreeText)
            TextFormField(
              controller: controller,
              onChanged: onChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your answer',
                hintText: 'Type your answer here',
                border: OutlineInputBorder(),
              ),
            )
          else
            ...question.options.map(
              (option) => _OptionTile(
                label: option,
                selected: value == option,
                onTap: () => onChanged(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    key: ValueKey(selected),
                    color: selected ? colors.primary : colors.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
