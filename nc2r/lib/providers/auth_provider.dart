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

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final result = await api.login(email, password);
      api.setToken(result.token);
      await ref.read(tokenStorageProvider).write(result.token);
      return result.user;
    });
  }

  Future<void> register(
      String name, String email, String password, String passwordConfirmation) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final result = await api.register(name, email, password, passwordConfirmation);
      api.setToken(result.token);
      await ref.read(tokenStorageProvider).write(result.token);
      return result.user;
    });
  }

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
    Future<({AppUser user, String token})> Function(ApiService, String) exchange,
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
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

/// Convenience selector: true while a user is logged in.
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).value != null,
);
