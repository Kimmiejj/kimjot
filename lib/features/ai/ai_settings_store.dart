import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_models.dart';

class AiSettingsStore extends ChangeNotifier {
  AiSettingsStore._();

  static final AiSettingsStore instance = AiSettingsStore._();

  static const _modeKey = 'ai.mode';
  static const _aiConsentKey = 'ai.enabled_consent';
  static const _slipVisionConsentKey = 'ai.slip_vision_consent';
  static const _buildBackendUrl = String.fromEnvironment('AI_BACKEND_URL');
  static const _productionBackendUrl = 'https://kimjot.vercel.app';

  AiMode _mode = AiMode.auto;
  bool _aiConsent = false;
  bool _slipVisionConsent = false;
  bool _loaded = false;

  AiMode get mode => _mode;
  bool get aiConsent => _aiConsent;
  bool get slipVisionConsent => _slipVisionConsent;
  String get backendUrl => _buildBackendUrl.trim().isNotEmpty
      ? _buildBackendUrl.trim()
      : _productionBackendUrl;

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_modeKey);
    _mode = AiMode.values.firstWhere(
      (mode) => mode.wireValue == savedMode,
      orElse: () => AiMode.auto,
    );
    _aiConsent = preferences.getBool(_aiConsentKey) ?? false;
    _slipVisionConsent = preferences.getBool(_slipVisionConsentKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AiMode mode) async {
    _mode = mode;
    _loaded = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeKey, mode.wireValue);
  }

  Future<void> setAiConsent(bool value) async {
    _aiConsent = value;
    if (!value) _slipVisionConsent = false;
    _loaded = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_aiConsentKey, value);
    if (!value) await preferences.setBool(_slipVisionConsentKey, false);
  }

  Future<void> setSlipVisionConsent(bool value) async {
    if (value && !_aiConsent) return;
    _slipVisionConsent = value;
    _loaded = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_slipVisionConsentKey, value);
  }
}
