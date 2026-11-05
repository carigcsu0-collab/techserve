/// Public links shown in the About, Help, and Rate screens.
/// Set at build time, e.g. --dart-define=PRIVACY_POLICY_URL=https://...
/// An empty value hides the related menu entry.
class AppLinks {
  AppLinks._();

  static const storeUrl = String.fromEnvironment('STORE_URL');
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
}
