class AppConfig {
  const AppConfig._();

  static const _defaultGoogleServerClientId =
      '193387033943-3gccqmdnssbnutvj3bu1ip4akss6s5ef.apps.googleusercontent.com';

  static const _googleServerClientIdOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static String get googleServerClientId {
    if (_googleServerClientIdOverride.isNotEmpty) {
      return _googleServerClientIdOverride;
    }

    return _defaultGoogleServerClientId;
  }
}
