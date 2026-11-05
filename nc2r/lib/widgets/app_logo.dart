import 'package:flutter/material.dart';

/// The NC2R logo, shown from the same image used for the app icon.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Wraps [AppLogo] with a one-shot "pop in" entrance: scales up with a
/// slight overshoot and fades/rotates in, for splash screens and the
/// login header.
class AnimatedAppLogo extends StatefulWidget {
  final double size;

  const AnimatedAppLogo({super.key, this.size = 96});

  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    final spin = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: RotationTransition(
          turns: Tween<double>(begin: -0.06, end: 0).animate(spin),
          child: AppLogo(size: widget.size),
        ),
      ),
    );
  }
}

