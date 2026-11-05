import 'package:flutter/material.dart';

/// Right-to-left slide transition for "deeper into the app" navigation
/// (e.g. Home → Lesson Detail → Quiz). Mirrors the platform's natural
/// forward-navigation direction instead of the default abrupt cut.
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            // The outgoing page eases slightly left + fades, so the two
            // pages don't feel like they're just stacked on top of
            // each other.
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-0.05, 0),
              ).animate(secondaryAnimation),
              child: child,
            ),
          );
        },
      );
}

/// Slide-up + fade transition for modals / overlays / celebratory screens
/// (e.g. the Certificate screen).
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
