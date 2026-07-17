class AppConfig {
  const AppConfig._();

  static const _defaultGoogleServerClientId =
      '193387033943-3gccqmdnssbnutvj3bu1ip4akss6s5ef.apps.googleusercontent.com';

  static const _googleServerClientIdOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _recoveryBackendUrlOverride = String.fromEnvironment(
    'RECOVERY_BACKEND_URL',
  );

  static String get googleServerClientId {
    if (_googleServerClientIdOverride.isNotEmpty) {
      return _googleServerClientIdOverride;
    }

    return _defaultGoogleServerClientId;
  }

  static String get recoveryBackendUrl {
    if (_recoveryBackendUrlOverride.isNotEmpty) {
      return _recoveryBackendUrlOverride;
    }
    return 'https://kimjot.vercel.app';
  }
}
