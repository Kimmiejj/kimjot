import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

import 'recovery_key_escrow_service.dart';
import 'transaction_payload_cipher.dart';

enum TransactionEncryptionAccess {
  setupRequired,
  recoveryKeyRequired,
  unlocked,
}

abstract interface class TransactionEncryptionController {
  Future<TransactionEncryptionAccess> prepareEncryption(String userId);

  Future<String> createRecoveryKey(String userId, {String? recoveryKey});

  Future<bool> unlockWithRecoveryKey(String userId, String recoveryKey);

  Future<bool> changeRecoveryKey({
    required String userId,
    required String currentRecoveryKey,
    required String newRecoveryKey,
  });

  Future<String> sendRecoveryKeyEmail(String userId);

  void clearEncryptionKey();
}

class TransactionEncryptionManager implements TransactionEncryptionController {
  TransactionEncryptionManager({
    FirebaseFirestore? firestore,
    TransactionPayloadCipher? cipher,
    RecoveryKeyEscrowService? escrowService,
  }) : this._(
         firestore,
         cipher ?? TransactionPayloadCipher(),
         escrowService ?? RecoveryKeyEscrowService(),
       );

  TransactionEncryptionManager._(
    this._firestore,
    this.cipher,
    this._escrowService,
  );

  static const _legacyKeyCheckText = 'kimjod-encryption-key-check-v1';
  static const _dataKeyMarker = 'kimjod-data-key-v2';

  final FirebaseFirestore? _firestore;
  final RecoveryKeyEscrowService _escrowService;
  final TransactionPayloadCipher cipher;

  String? _activeUserId;
  SecretKey? _activeDataKey;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<TransactionEncryptionAccess> prepareEncryption(String userId) async {
    if (_activeUserId == userId && _activeDataKey != null) {
      return TransactionEncryptionAccess.unlocked;
    }
    clearEncryptionKey();

    final config = await _loadConfig(userId);
    return config == null
        ? TransactionEncryptionAccess.setupRequired
        : TransactionEncryptionAccess.recoveryKeyRequired;
  }

  @override
  Future<String> createRecoveryKey(String userId, {String? recoveryKey}) async {
    final selectedRecoveryKey = recoveryKey?.trim() ?? '';
    if (TransactionPayloadCipher.normalizeRecoveryKey(
          selectedRecoveryKey,
        ).length <
        TransactionPayloadCipher.minimumRecoveryKeyLength) {
      throw const TransactionEncryptionException(
        'A manually created recovery key of at least 12 characters is required.',
      );
    }
    final reference = _configReference(userId);
    final existing = await reference.get();
    if (existing.exists) {
      throw const TransactionEncryptionException(
        'Encryption is already configured for this account.',
      );
    }

    const keyVersion = 1;
    final escrowId = base64UrlEncode(cipher.generateSalt());
    final salt = cipher.generateSalt();
    final wrappingKey = await cipher.deriveKey(
      userId: userId,
      recoveryKey: selectedRecoveryKey,
      salt: salt,
    );
    final dataKey = await cipher.newDataKey();
    final wrappedDataKey = await _wrapDataKey(
      userId: userId,
      keyVersion: keyVersion,
      dataKey: dataKey,
      wrappingKey: wrappingKey,
    );

    await _escrowService.backupKey(
      userId: userId,
      recoveryKey: selectedRecoveryKey,
      keyVersion: keyVersion,
      escrowId: escrowId,
    );

    await _db.runTransaction((transaction) async {
      final current = await transaction.get(reference);
      if (current.exists) {
        throw const TransactionEncryptionException(
          'Encryption is already configured for this account.',
        );
      }
      transaction.set(reference, <String, Object?>{
        'version': 2,
        'kdf': 'argon2id',
        'salt': base64UrlEncode(salt),
        'wrappedDataKey': wrappedDataKey,
        'keyVersion': keyVersion,
        'escrowId': escrowId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    _setActiveDataKey(userId, dataKey);
    return selectedRecoveryKey;
  }

  @override
  Future<bool> unlockWithRecoveryKey(String userId, String recoveryKey) async {
    final config = await _loadConfig(userId);
    if (config == null) return false;

    try {
      final dataKey = await _dataKeyFromRecoveryKey(
        userId: userId,
        recoveryKey: recoveryKey,
        config: config,
      );
      _setActiveDataKey(userId, dataKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> changeRecoveryKey({
    required String userId,
    required String currentRecoveryKey,
    required String newRecoveryKey,
  }) async {
    final normalizedNewKey = TransactionPayloadCipher.normalizeRecoveryKey(
      newRecoveryKey,
    );
    if (normalizedNewKey.length <
        TransactionPayloadCipher.minimumRecoveryKeyLength) {
      throw const TransactionEncryptionException(
        'The new recovery key must be at least 12 characters.',
      );
    }
    if (normalizedNewKey ==
        TransactionPayloadCipher.normalizeRecoveryKey(currentRecoveryKey)) {
      throw const TransactionEncryptionException(
        'The new recovery key must differ from the current key.',
      );
    }
    final reference = _configReference(userId);
    final config = await _loadConfig(userId);
    if (config == null) return false;

    final SecretKey dataKey;
    try {
      dataKey = await _dataKeyFromRecoveryKey(
        userId: userId,
        recoveryKey: currentRecoveryKey,
        config: config,
      );
    } catch (_) {
      return false;
    }

    final currentVersion = (config['keyVersion'] as num?)?.toInt() ?? 0;
    final nextVersion = currentVersion + 1;
    final escrowId = base64UrlEncode(cipher.generateSalt());
    final salt = cipher.generateSalt();
    final wrappingKey = await cipher.deriveKey(
      userId: userId,
      recoveryKey: newRecoveryKey,
      salt: salt,
    );
    final wrappedDataKey = await _wrapDataKey(
      userId: userId,
      keyVersion: nextVersion,
      dataKey: dataKey,
      wrappingKey: wrappingKey,
    );

    await _escrowService.backupKey(
      userId: userId,
      recoveryKey: newRecoveryKey,
      keyVersion: nextVersion,
      escrowId: escrowId,
    );

    await _db.runTransaction((transaction) async {
      final latest = await transaction.get(reference);
      final latestData = latest.data();
      final latestVersion = (latestData?['keyVersion'] as num?)?.toInt() ?? 0;
      if (!latest.exists || latestVersion != currentVersion) {
        throw const TransactionEncryptionException(
          'Recovery key changed on another device. Try again.',
        );
      }
      transaction.set(reference, <String, Object?>{
        'version': 2,
        'kdf': 'argon2id',
        'salt': base64UrlEncode(salt),
        'wrappedDataKey': wrappedDataKey,
        'keyVersion': nextVersion,
        'escrowId': escrowId,
        'createdAt': config['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    _setActiveDataKey(userId, dataKey);
    return true;
  }

  @override
  Future<String> sendRecoveryKeyEmail(String userId) {
    return _escrowService.sendRecoveryEmail(userId: userId);
  }

  @override
  void clearEncryptionKey() {
    _activeUserId = null;
    _activeDataKey = null;
  }

  Future<Map<String, Object?>> encryptPayload({
    required String userId,
    required String documentId,
    required DateTime transactionDate,
    required Map<String, Object?> payload,
  }) {
    return cipher.encryptMap(
      clearText: payload,
      key: _requireDataKey(userId),
      associatedData: transactionAssociatedData(
        userId: userId,
        documentId: documentId,
        transactionDate: transactionDate,
      ),
    );
  }

  Future<Map<String, dynamic>> decryptPayload({
    required String userId,
    required String documentId,
    required DateTime transactionDate,
    required Map<String, dynamic> envelope,
  }) {
    return cipher.decryptMap(
      envelope: envelope,
      key: _requireDataKey(userId),
      associatedData: transactionAssociatedData(
        userId: userId,
        documentId: documentId,
        transactionDate: transactionDate,
      ),
    );
  }

  String transactionAssociatedData({
    required String userId,
    required String documentId,
    required DateTime transactionDate,
  }) {
    return 'kimjod.transaction.v1|$userId|$documentId|'
        '${transactionDate.toUtc().millisecondsSinceEpoch}';
  }

  Future<Map<String, Object?>> _wrapDataKey({
    required String userId,
    required int keyVersion,
    required SecretKey dataKey,
    required SecretKey wrappingKey,
  }) async {
    return cipher.encryptMap(
      clearText: <String, Object?>{
        'marker': _dataKeyMarker,
        'userId': userId,
        'dataKey': base64UrlEncode(await dataKey.extractBytes()),
      },
      key: wrappingKey,
      associatedData: _dataKeyAssociatedData(userId, keyVersion),
    );
  }

  Future<SecretKey> _dataKeyFromRecoveryKey({
    required String userId,
    required String recoveryKey,
    required Map<String, dynamic> config,
  }) async {
    final salt = base64Url.decode(config['salt'] as String);
    final wrappingKey = await cipher.deriveKey(
      userId: userId,
      recoveryKey: recoveryKey,
      salt: salt,
    );

    if (config['version'] == 2) {
      final rawEnvelope = config['wrappedDataKey'];
      final keyVersion = (config['keyVersion'] as num?)?.toInt();
      if (rawEnvelope is! Map || keyVersion == null) {
        throw const TransactionDecryptionException(
          'Encrypted data key is missing.',
        );
      }
      final clear = await cipher.decryptMap(
        envelope: Map<String, dynamic>.from(rawEnvelope),
        key: wrappingKey,
        associatedData: _dataKeyAssociatedData(userId, keyVersion),
      );
      if (clear['marker'] != _dataKeyMarker || clear['userId'] != userId) {
        throw const TransactionDecryptionException(
          'Encrypted data key owner mismatch.',
        );
      }
      return SecretKey(base64Url.decode(clear['dataKey'] as String));
    }

    if (!await _isValidLegacyKey(
      userId: userId,
      key: wrappingKey,
      config: config,
    )) {
      throw const TransactionDecryptionException('Recovery key is incorrect.');
    }
    return wrappingKey;
  }

  Future<bool> _isValidLegacyKey({
    required String userId,
    required SecretKey key,
    required Map<String, dynamic> config,
  }) async {
    final rawKeyCheck = config['keyCheck'];
    if (rawKeyCheck is! Map) return false;
    final clear = await cipher.decryptMap(
      envelope: Map<String, dynamic>.from(rawKeyCheck),
      key: key,
      associatedData: 'kimjod.key-check.v1|$userId',
    );
    return clear['marker'] == _legacyKeyCheckText && clear['userId'] == userId;
  }

  String _dataKeyAssociatedData(String userId, int keyVersion) {
    return 'kimjod.data-key.v2|$userId|$keyVersion';
  }

  Future<Map<String, dynamic>?> _loadConfig(String userId) async {
    final reference = _configReference(userId);
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await reference.get().timeout(const Duration(seconds: 5));
    } catch (_) {
      snapshot = await reference.get(const GetOptions(source: Source.cache));
    }
    return snapshot.data();
  }

  SecretKey _requireDataKey(String userId) {
    if (_activeUserId != userId || _activeDataKey == null) {
      throw const TransactionEncryptionException(
        'Transaction encryption is locked.',
      );
    }
    return _activeDataKey!;
  }

  void _setActiveDataKey(String userId, SecretKey key) {
    _activeUserId = userId;
    _activeDataKey = key;
  }

  DocumentReference<Map<String, dynamic>> _configReference(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('security')
        .doc('transactionEncryption');
  }
}
