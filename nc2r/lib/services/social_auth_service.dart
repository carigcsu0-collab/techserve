import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when the user backs out of a provider's sign-in screen (not an error).
class SocialLoginCancelled implements Exception {}

/// Gets a provider token on the device; the backend verifies it.
/// Buttons only show when the matching value is passed at launch:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
///               --dart-define=FACEBOOK_ENABLED=true
class SocialAuthService {
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const facebookEnabled = bool.fromEnvironment('FACEBOOK_ENABLED');

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get googleAvailable => googleServerClientId.isNotEmpty && (kIsWeb || _mobile);
  static bool get facebookAvailable => facebookEnabled && (kIsWeb || _mobile);
  static bool get anyAvailable => googleAvailable || facebookAvailable;

  static bool _googleReady = false;

  Future<String> googleIdToken() async {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);
      _googleReady = true;
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('Google did not return an ID token.');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SocialLoginCancelled();
      rethrow;
    }
  }

  Future<String> facebookAccessToken() async {
    final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
    switch (result.status) {
      case LoginStatus.success:
        return result.accessToken!.token;
      case LoginStatus.cancelled:
        throw SocialLoginCancelled();
      default:
        throw Exception(result.message ?? 'Facebook sign-in failed.');
    }
  }
}
