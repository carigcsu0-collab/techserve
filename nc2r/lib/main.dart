import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin_shell.dart';
import 'screens/learner_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/update_service.dart';

void main() {
  runApp(const ProviderScope(child: NC2RApp()));
}

class NC2RApp extends ConsumerWidget {
  const NC2RApp({super.key});

  static const _maroon = Color(0xFF800000);
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TechServe',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const AuthGate(),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _maroon,
          brightness: brightness,
        ).copyWith(
          primary: brightness == Brightness.dark
              ? const Color(0xFFE57373)
              : _maroon,
          secondary: _gold,
        );

    return ThemeData(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
    );
  }
}

/// Routes between splash / login / learner / admin based on auth state,
/// cross-fading between them instead of an abrupt widget swap.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Apps are often resumed rather than relaunched, so re-check then too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateService.checkAndPrompt(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child = const AdminShell();
        stateKey = 'admin';
      } else {
        child = const LearnerShell();
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
