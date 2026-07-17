import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricRecoveryKeyStore {
  Future<bool> hasSavedKey(String userId);

  Future<void> saveKey(String userId, String recoveryKey);

  Future<String?> authenticateAndReadKey({
    required String userId,
    required bool isThai,
  });

  Future<void> deleteKey(String userId);
}

class DeviceBiometricRecoveryKeyStore implements BiometricRecoveryKeyStore {
  DeviceBiometricRecoveryKeyStore({
    LocalAuthentication? authentication,
    FlutterSecureStorage? storage,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'transaction_recovery_key.';

  final LocalAuthentication _authentication;
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasSavedKey(String userId) async {
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      if (!await _authentication.canCheckBiometrics) return false;
      return await _storage.containsKey(key: '$_keyPrefix$userId');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveKey(String userId, String recoveryKey) {
    return _storage.write(key: '$_keyPrefix$userId', value: recoveryKey);
  }

  @override
  Future<String?> authenticateAndReadKey({
    required String userId,
    required bool isThai,
  }) async {
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: isThai
            ? 'ยืนยันด้วยใบหน้าหรือลายนิ้วมือเพื่อปลดล็อกข้อมูลรายการ'
            : 'Use face or fingerprint recognition to unlock transaction data.',
        biometricOnly: true,
      );
      if (!authenticated) return null;
      return _storage.read(key: '$_keyPrefix$userId');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteKey(String userId) {
    return _storage.delete(key: '$_keyPrefix$userId');
  }
}
