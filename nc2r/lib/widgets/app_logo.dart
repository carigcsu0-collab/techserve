import 'package:flutter/material.dart';

/// The NC2R mark: a maroon badge (certification) with a gold graduation
/// cap (learning) and a small "verified" checkmark medallion. Pure vector
/// (CustomPainter) so it's crisp at any size and needs no image assets.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF800000).withValues(alpha: 0.35),
              blurRadius: size * 0.25,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: CustomPaint(painter: _LogoPainter()),
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

class _LogoPainter extends CustomPainter {
  static const _maroonDark = Color(0xFF5C0000);
  static const _maroonLight = Color(0xFFA02020);
  static const _gold = Color(0xFFFFD700);
  static const _goldShade = Color(0xFFB8860B);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Badge background.
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [_maroonLight, _maroonDark],
        center: Alignment(-0.35, -0.35),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Gold ring.
    final ringWidth = radius * 0.07;
    canvas.drawCircle(
      center,
      radius - ringWidth / 2,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth,
    );

    // Graduation cap — diamond board + head band.
    final capCenter = Offset(center.dx, center.dy - radius * 0.12);
    final capWidth = radius * 1.15;
    final capHeight = radius * 0.5;
    final capPaint = Paint()..color = _gold;

    final diamond = Path()
      ..moveTo(capCenter.dx, capCenter.dy - capHeight * 0.55)
      ..lineTo(capCenter.dx + capWidth / 2, capCenter.dy)
      ..lineTo(capCenter.dx, capCenter.dy + capHeight * 0.55)
      ..lineTo(capCenter.dx - capWidth / 2, capCenter.dy)
      ..close();
    canvas.drawPath(diamond, capPaint);

    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(capCenter.dx, capCenter.dy + capHeight * 0.6),
        width: capWidth * 0.5,
        height: capHeight * 0.42,
      ),
      Radius.circular(radius * 0.04),
    );
    canvas.drawRRect(band, capPaint);

    // Button + tassel.
    final tasselPaint = Paint()
      ..color = _goldShade
      ..strokeWidth = radius * 0.045
      ..strokeCap = StrokeCap.round;
    final tasselEnd = Offset(
      capCenter.dx + radius * 0.26,
      capCenter.dy + radius * 0.5,
    );
    canvas.drawLine(capCenter, tasselEnd, tasselPaint);
    canvas.drawCircle(tasselEnd, radius * 0.06, Paint()..color = _goldShade);
    canvas.drawCircle(capCenter, radius * 0.045, Paint()..color = _goldShade);

    // "Verified" checkmark medallion, bottom-right.
    final badgeCenter = Offset(
      center.dx + radius * 0.6,
      center.dy + radius * 0.6,
    );
    final badgeRadius = radius * 0.36;
    canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      badgeCenter,
      badgeRadius - radius * 0.025,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05,
    );

    final checkPaint = Paint()
      ..color = _maroonDark
      ..strokeWidth = radius * 0.09
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(badgeCenter.dx - badgeRadius * 0.45, badgeCenter.dy)
      ..lineTo(badgeCenter.dx - badgeRadius * 0.1, badgeCenter.dy + badgeRadius * 0.35)
      ..lineTo(badgeCenter.dx + badgeRadius * 0.5, badgeCenter.dy - badgeRadius * 0.4);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
