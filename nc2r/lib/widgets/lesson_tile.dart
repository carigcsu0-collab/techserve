import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/lesson.dart';
import 'lesson_avatar.dart';
import 'tap_scale.dart';

class LessonTile extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const LessonTile({super.key, required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = !lesson.isUnlocked;
    final colors = Theme.of(context).colorScheme;

    return TapScale(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: locked ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            // Locked lessons don't navigate anywhere, so there's no matching
            // Hero on the far side — Flutter simply renders it statically.
            leading: Hero(
              tag: 'lesson-avatar-${lesson.id}',
              child: LessonAvatar(lesson: lesson, radius: 20),
            ),
            title: Text(lesson.title,
                style: TextStyle(color: locked ? colors.outline : null)),
            subtitle: Text(
              lesson.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _UnlockTrailingIcon(lesson: lesson),
            onTap: null, // handled by TapScale so tap feedback is visible
          ),
        ),
      ),
    );
  }
}

/// The trailing lock/play icon. Keyed on the locked state so that the
/// moment a lesson unlocks, [AnimatedSwitcher] swaps it out — the new
/// (play/image) icon spawns via [_UnlockPop], which grows in from green
/// with a small shake before settling to the theme color, while the old
/// lock icon shrinks and fades away.
class _UnlockTrailingIcon extends StatelessWidget {
  final Lesson lesson;

  const _UnlockTrailingIcon({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final locked = !lesson.isUnlocked;
    final colors = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: RotationTransition(
          turns: Tween<double>(begin: 0.08, end: 0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      child: locked
          ? Icon(Icons.lock_outline, key: const ValueKey('locked'), color: colors.outline)
          : _UnlockPop(
              key: const ValueKey('unlocked'),
              targetColor: colors.primary,
              icon: lesson.isVideo ? Icons.play_circle : Icons.image,
            ),
    );
  }
}

/// One-shot "unlock celebration": the icon spawns green, shakes briefly,
/// grows in, then settles into [targetColor]. Runs once per instance
/// (i.e. once per unlock), driven by the widget's own lifetime rather
/// than external state, so it can't be accidentally re-triggered by
/// unrelated rebuilds.
class _UnlockPop extends StatefulWidget {
  final IconData icon;
  final Color targetColor;

  const _UnlockPop({super.key, required this.icon, required this.targetColor});

  @override
  State<_UnlockPop> createState() => _UnlockPopState();
}

class _UnlockPopState extends State<_UnlockPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Shake dies out as the animation progresses.
        final shake = math.sin(t * math.pi * 6) * (1 - t) * 0.25;
        final scale = Curves.elasticOut.transform(t).clamp(0.0, 1.3);
        final color = Color.lerp(Colors.green, widget.targetColor, t);
        return Transform.rotate(
          angle: shake,
          child: Transform.scale(
            scale: scale,
            child: Icon(widget.icon, color: color),
          ),
        );
      },
    );
  }
}
