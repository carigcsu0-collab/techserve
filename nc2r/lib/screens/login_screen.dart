import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/social_auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/motion.dart';
import '../widgets/tap_scale.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLogin = true;

  /// Set while the user must enter the emailed code before signing in.
  String? _pendingEmail;
  bool _verifying = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = ref.read(authProvider.notifier);
    final String? pending;
    if (_isLogin) {
      pending = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      pending = await auth.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _confirmController.text,
      );
    }
    if (pending != null && mounted) {
      setState(() {
        _pendingEmail = pending;
        _otpController.clear();
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showMessage('Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).verifyEmail(_pendingEmail!, code);
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authProvider.notifier).resendVerification(_pendingEmail!);
      if (mounted) _showMessage('A new code has been sent to your email.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  void _backToForm() {
    setState(() {
      _pendingEmail = null;
      _otpController.clear();
    });
  }

  Widget _buildOtpStep() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Check your email',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to $_pendingEmail. It expires in 10 minutes.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Verification code',
            counterText: '',
          ),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        PressableScale(
          child: FilledButton(
            onPressed: _verifying ? null : _verify,
            child: _verifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify'),
          ),
        ),
        TextButton(onPressed: _resend, child: const Text('Resend code')),
        TextButton(onPressed: _backToForm, child: const Text('Back')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      body: Column(
        children: [
          // Brand header — the maroon->darker maroon gradient echoes the
          // splash screen so login doesn't feel like a separate app.
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              bottom: 28,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5C0000), Color(0xFF800000)],
              ),
            ),
            child: Column(
              children: [
                const AnimatedAppLogo(size: 84),
                const SizedBox(height: 16),
                Text(
                  'NC2R',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'NC II Reviewer',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeSlideIn(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: _pendingEmail != null
                    ? _buildOtpStep()
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? 'Welcome back' : 'Create your account',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              alignment: Alignment.topCenter,
                              child: !_isLogin
                                  ? Column(
                                      children: [
                                        TextFormField(
                                          controller: _nameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Full name',
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'At least 8 characters'
                                  : null,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              alignment: Alignment.topCenter,
                              child: !_isLogin
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _confirmController,
                                          obscureText: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Confirm password',
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                            ),
                                          ),
                                          validator: (v) =>
                                              v != _passwordController.text
                                              ? 'Passwords do not match'
                                              : null,
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 24),
                            PressableScale(
                              child: FilledButton(
                                onPressed: isLoading ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: isLoading
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isLogin
                                              ? 'Sign In'
                                              : 'Create Account',
                                          key: const ValueKey('label'),
                                        ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin
                                    ? 'No account? Register'
                                    : 'Already have an account? Sign in',
                              ),
                            ),
                            if (SocialAuthService.anyAvailable) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: const [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text('or continue with'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (SocialAuthService.googleAvailable)
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => ref
                                            .read(authProvider.notifier)
                                            .loginWithGoogle(),
                                  icon: const Icon(
                                    Icons.g_mobiledata,
                                    size: 28,
                                  ),
                                  label: const Text('Google'),
                                ),
                              if (SocialAuthService.googleAvailable &&
                                  SocialAuthService.facebookAvailable)
                                const SizedBox(height: 10),
                              if (SocialAuthService.facebookAvailable)
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => ref
                                            .read(authProvider.notifier)
                                            .loginWithFacebook(),
                                  icon: const Icon(Icons.facebook),
                                  label: const Text('Facebook'),
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
