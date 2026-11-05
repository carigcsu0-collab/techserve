import 'package:flutter/material.dart';

/// Wraps [child] in its own tap handler and shrinks it slightly while
/// pressed, for plain tappable surfaces (cards, tiles) that don't already
/// have their own gesture recognizer/ripple driving `onTap`.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _scale = _bounceScale(_controller, widget.scale);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (widget.onTap == null) return;
    // Pressing eases down; releasing overshoots slightly back up.
    if (pressed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Press-down / release-bounce scale shared by [TapScale] and [PressableScale].
/// Value 1 is the resting size; reversing eases toward [pressedScale], and
/// forward overshoots back past 1 with [Curves.easeOutBack].
Animation<double> _bounceScale(
  AnimationController controller,
  double pressedScale,
) {
  final curved = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeOut,
  );
  return Tween<double>(begin: pressedScale, end: 1).animate(curved);
}

/// Purely observes raw pointer down/up/cancel events (via [Listener], which
/// never enters the gesture arena) to drive a press-scale animation around
/// an existing tappable widget — e.g. a [FilledButton] — without competing
/// with, or stealing, its own tap recognizer.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;

  const PressableScale({super.key, required this.child, this.scale = 0.96});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _scale = _bounceScale(_controller, widget.scale);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.reverse(),
      onPointerUp: (_) => _controller.forward(),
      onPointerCancel: (_) => _controller.forward(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
