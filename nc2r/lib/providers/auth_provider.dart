import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';
import '../services/social_auth_service.dart';
import 'api_provider.dart';

/// Holds the logged-in user. `null` when logged out.
/// The Sanctum token lives on [ApiService] (attached to every request)
/// and is persisted in secure storage so sessions survive restarts.
class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null) return null;

    final api = ref.read(apiServiceProvider);
    api.setToken(token);

    try {
      return await api.fetchUser();
    } catch (_) {
      // Token expired or server unreachable — clear the stale session.
      api.setToken(null);
      await storage.clear();
      return null;
    }
  }

  /// Returns the email to verify when the account needs a code, otherwise null.
  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.login(email, password);
      api.setToken(result.token);
      await ref.read(tokenStorageProvider).write(result.token);
      state = AsyncValue.data(result.user);
      return null;
    } on ApiException catch (e) {
      if (e.code == 'email_unverified') {
        state = const AsyncValue.data(null);
        return email;
      }
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Returns the email to verify once the code has been sent, otherwise null.
  Future<String?> register(String name, String email) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(apiServiceProvider).register(name, email);
      state = const AsyncValue.data(null);
      return email;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Confirms the emailed code. Returns a setup token when a password must be
  /// chosen next, or null if the user was signed in. Errors are rethrown
  /// so the OTP screen can show them without replacing the pending step.
  Future<String?> verifyEmail(String email, String code) async {
    final result = await ref.read(apiServiceProvider).verifyEmail(email, code);
    if (result.setupToken != null) return result.setupToken;
    await _signIn(result.user!, result.token!);
    return null;
  }

  Future<void> setPassword(
    String email,
    String setupToken,
    String password,
    String passwordConfirmation,
  ) async {
    final result = await ref
        .read(apiServiceProvider)
        .setPassword(email, setupToken, password, passwordConfirmation);
    await _signIn(result.user, result.token);
  }

  Future<void> _signIn(AppUser user, String token) async {
    ref.read(apiServiceProvider).setToken(token);
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncValue.data(user);
  }

  Future<void> resendVerification(String email) =>
      ref.read(apiServiceProvider).resendVerification(email);

  /// Runs a social sign-in. A cancelled provider screen leaves state untouched.
  Future<void> loginWithGoogle() => _social(
    (social) => social.googleIdToken(),
    (api, token) => api.loginWithGoogle(token),
  );

  Future<void> loginWithFacebook() => _social(
    (social) => social.facebookAccessToken(),
    (api, token) => api.loginWithFacebook(token),
  );

  Future<void> _social(
    Future<String> Function(SocialAuthService) getToken,
    Future<({AppUser user, String token})> Function(ApiService, String)
    exchange,
  ) async {
    final previous = state;
    state = const AsyncValue.loading();
    try {
      final providerToken = await getToken(SocialAuthService());
      final api = ref.read(apiServiceProvider);
      final result = await exchange(api, providerToken);
      api.setToken(result.token);
      await ref.read(tokenStorageProvider).write(result.token);
      state = AsyncValue.data(result.user);
    } on SocialLoginCancelled {
      state = previous;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(apiServiceProvider).logout();
    } finally {
      await ref.read(tokenStorageProvider).clear();
      state = const AsyncValue.data(null);
    }
  }

  /// Called when the course is completed so the certificate link is
  /// immediately available on the user without a re-login.
  void setCertificate(String certificateUrl) {
    final user = state.value;
    if (user != null) {
      state = AsyncValue.data(user.copyWith(certificateUrl: certificateUrl));
    }
  }

  Future<void> updateName(String name) async {
    final updated = await ref.read(apiServiceProvider).updateProfile(name);
    state = AsyncValue.data(updated);
  }

  Future<void> updateProfileDetails({
    required String name,
    required String bio,
    required String phone,
    required String location,
  }) async {
    final updated = await ref
        .read(apiServiceProvider)
        .updateProfile(name, bio: bio, phone: phone, location: location);
    state = AsyncValue.data(updated);
  }

  Future<void> uploadAvatar(String filePath) async {
    final updated = await ref.read(apiServiceProvider).uploadAvatar(filePath);
    state = AsyncValue.data(updated);
  }

  Future<void> removeAvatar() async {
    final updated = await ref.read(apiServiceProvider).removeAvatar();
    state = AsyncValue.data(updated);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);

/// Convenience selector: true while a user is logged in.
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).value != null,
);
