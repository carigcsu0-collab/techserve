import 'package:flutter/material.dart';

import '../models/qualification.dart';

/// Card for one qualification, showing its progress when the learner has any.
class QualificationCard extends StatelessWidget {
  final Qualification qualification;
  final VoidCallback onTap;

  const QualificationCard({
    super.key,
    required this.qualification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = qualification;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      q.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (q.isCompleted)
                    const Icon(Icons.verified, color: Colors.green),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                q.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: q.progress,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${q.completedCount}/${q.lessonCount}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
