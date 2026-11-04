import 'package:flutter/material.dart';

import '../models/lesson.dart';

/// The numbered/completed/locked status circle for a lesson. Shared by
/// [LessonTile] (small, in the list) and [LessonDetailScreen] (large, in
/// the header) so a [Hero] can smoothly expand one into the other.
class LessonAvatar extends StatelessWidget {
  final Lesson lesson;
  final double radius;

  const LessonAvatar({super.key, required this.lesson, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final locked = !lesson.isUnlocked;
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: lesson.isCompleted
          ? Colors.green
          : locked
              ? colors.surfaceContainerHighest
              : colors.primary,
      child: lesson.isCompleted
          ? Icon(Icons.check, color: Colors.white, size: radius)
          : locked
              ? Icon(Icons.lock, color: colors.outline, size: radius)
              : Text(
                  '${lesson.orderIndex}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
    );
  }
}
