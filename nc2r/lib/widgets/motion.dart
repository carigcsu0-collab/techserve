import 'dart:async';

import 'package:flutter/material.dart';

/// Scales and fades [child] in with a soft overshoot, optionally after a
/// [delay]. Used for celebratory reveals (quiz result icon, certificate).
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Fades [child] in while it rises a few pixels into place. Used for
/// form and section entrances.
class FadeSlideIn extends StatefulWidget {
  final Widget child;

  const FadeSlideIn({super.key, required this.child});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// A [LinearProgressIndicator] whose fill glides to [value] instead of
/// snapping when it changes.
class AnimatedLinearProgress extends StatelessWidget {
  final double value;

  const AnimatedLinearProgress({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LinearProgressIndicator(value: v),
    );
  }
}

/// Counts up from 0 to [value] when first shown and again whenever [value]
/// changes, e.g. "Score: 0% → 85%".
class CountUpText extends StatelessWidget {
  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;

  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix$v$suffix', style: style),
    );
  }
}
