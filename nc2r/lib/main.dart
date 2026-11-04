import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/admin_lessons_screen.dart';
import 'screens/lesson_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: NC2RApp()));
}

class NC2RApp extends StatelessWidget {
  const NC2RApp({super.key});

  static const _maroon = Color(0xFF800000);
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _maroon).copyWith(
      primary: _maroon,
      secondary: _gold,
    );

    return MaterialApp(
      title: 'NC2R — NC II Reviewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: _maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: _maroon.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _maroon, width: 1.6),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Routes between splash / login / learner / admin based on auth state,
/// cross-fading between them instead of an abrupt widget swap.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    final Widget child;
    final Object stateKey;
    if (auth.isLoading && !auth.hasValue) {
      child = const SplashScreen();
      stateKey = 'splash';
    } else {
      final user = auth.value;
      if (user == null) {
        child = const LoginScreen();
        stateKey = 'login';
      } else if (user.isAdmin) {
        child = const AdminLessonsScreen();
        stateKey = 'admin';
      } else {
        child = const LessonListScreen();
        stateKey = 'learner';
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (widget, animation) =>
          FadeTransition(opacity: animation, child: widget),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
