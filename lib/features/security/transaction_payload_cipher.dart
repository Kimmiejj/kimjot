import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

class TransactionPayloadCipher {
  TransactionPayloadCipher({
    Argon2id? keyDerivation,
    AesGcm? cipher,
    Random? random,
  }) : _keyDerivation =
           keyDerivation ??
           DartArgon2id(
             memory: 19 * 1024,
             parallelism: 1,
             iterations: 2,
             hashLength: 32,
             maxIsolates: 1,
           ),
       _cipher = cipher ?? AesGcm.with256bits(),
       _random = random ?? Random.secure();

  static const envelopeVersion = 1;
  static const minimumRecoveryKeyLength = 12;

  final Argon2id _keyDerivation;
  final AesGcm _cipher;
  final Random _random;

  List<int> generateSalt() {
    return List<int>.generate(16, (_) => _random.nextInt(256));
  }

  Future<SecretKey> newDataKey() => _cipher.newSecretKey();

  Future<SecretKey> deriveKey({
    required String userId,
    required String recoveryKey,
    required List<int> salt,
  }) {
    final normalized = normalizeRecoveryKey(recoveryKey);
    if (normalized.length < minimumRecoveryKeyLength) {
      throw const TransactionEncryptionException(
        'Recovery key must be at least 12 characters.',
      );
    }

    return _keyDerivation.deriveKeyFromPassword(
      password: normalized,
      nonce: <int>[...salt, ...utf8.encode(userId)],
    );
  }

  Future<Map<String, Object?>> encryptMap({
    required Map<String, Object?> clearText,
    required SecretKey key,
    required String associatedData,
  }) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(clearText)),
      secretKey: key,
      aad: utf8.encode(associatedData),
    );

    return <String, Object?>{
      'version': envelopeVersion,
      'nonce': base64UrlEncode(box.nonce),
      'ciphertext': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> decryptMap({
    required Map<String, dynamic> envelope,
    required SecretKey key,
    required String associatedData,
  }) async {
    try {
      if (envelope['version'] != envelopeVersion) {
        throw const TransactionDecryptionException(
          'Unsupported encrypted payload version.',
        );
      }

      final box = SecretBox(
        base64Url.decode(envelope['ciphertext'] as String),
        nonce: base64Url.decode(envelope['nonce'] as String),
        mac: Mac(base64Url.decode(envelope['mac'] as String)),
      );
      final clearBytes = await _cipher.decrypt(
        box,
        secretKey: key,
        aad: utf8.encode(associatedData),
      );
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const TransactionDecryptionException(
          'Encrypted payload is not a JSON object.',
        );
      }
      return decoded;
    } on TransactionDecryptionException {
      rethrow;
    } catch (_) {
      throw const TransactionDecryptionException(
        'Encrypted payload authentication failed.',
      );
    }
  }

  static String normalizeRecoveryKey(String value) {
    return value.trim().replaceAll(RegExp(r'[\s-]+'), '').toLowerCase();
  }

}

class TransactionEncryptionException implements Exception {
  const TransactionEncryptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TransactionDecryptionException extends TransactionEncryptionException {
  const TransactionDecryptionException(super.message);
}
