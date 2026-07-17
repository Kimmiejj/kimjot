import 'dart:math';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/features/security/transaction_payload_cipher.dart';

void main() {
  late TransactionPayloadCipher cipher;
  const userId = 'firebase-user-123';
  const recoveryKey =
      '0123-4567-89ab-cdef-0123-4567-89ab-cdef-0123-4567-89ab-cdef';
  final salt = List<int>.generate(16, (index) => index);

  setUp(() {
    cipher = TransactionPayloadCipher(
      keyDerivation: DartArgon2id(
        memory: 128,
        parallelism: 1,
        iterations: 1,
        hashLength: 32,
        maxIsolates: 1,
      ),
      random: Random(42),
    );
  });

  test('encrypts and decrypts a transaction payload', () async {
    final key = await cipher.deriveKey(
      userId: userId,
      recoveryKey: recoveryKey,
      salt: salt,
    );
    final envelope = await cipher.encryptMap(
      clearText: const <String, Object?>{
        'amount': 125.50,
        'type': 'expense',
        'note': 'Lunch',
      },
      key: key,
      associatedData: 'transaction|$userId|document-1',
    );

    expect(
      envelope.keys,
      containsAll(['version', 'nonce', 'ciphertext', 'mac']),
    );
    expect(envelope.toString(), isNot(contains('Lunch')));
    expect(envelope.toString(), isNot(contains('125.5')));

    final clear = await cipher.decryptMap(
      envelope: Map<String, dynamic>.from(envelope),
      key: key,
      associatedData: 'transaction|$userId|document-1',
    );

    expect(clear['amount'], 125.50);
    expect(clear['type'], 'expense');
    expect(clear['note'], 'Lunch');
  });

  test(
    'same recovery key derives a different key for another Google uid',
    () async {
      final ownerKey = await cipher.deriveKey(
        userId: userId,
        recoveryKey: recoveryKey,
        salt: salt,
      );
      final otherUserKey = await cipher.deriveKey(
        userId: 'another-firebase-user',
        recoveryKey: recoveryKey,
        salt: salt,
      );
      final ownerBytes = await ownerKey.extractBytes();
      final otherBytes = await otherUserKey.extractBytes();

      expect(otherBytes, isNot(equals(ownerBytes)));
    },
  );

  test('rejects a wrong recovery key', () async {
    final ownerKey = await cipher.deriveKey(
      userId: userId,
      recoveryKey: recoveryKey,
      salt: salt,
    );
    final wrongKey = await cipher.deriveKey(
      userId: userId,
      recoveryKey: 'wrong-recovery-key',
      salt: salt,
    );
    final envelope = await cipher.encryptMap(
      clearText: const <String, Object?>{'amount': 900},
      key: ownerKey,
      associatedData: 'owner-bound-data',
    );

    expect(
      () => cipher.decryptMap(
        envelope: Map<String, dynamic>.from(envelope),
        key: wrongKey,
        associatedData: 'owner-bound-data',
      ),
      throwsA(isA<TransactionDecryptionException>()),
    );
  });

  test('rejects modified ciphertext and associated metadata', () async {
    final key = await cipher.deriveKey(
      userId: userId,
      recoveryKey: recoveryKey,
      salt: salt,
    );
    final envelope = await cipher.encryptMap(
      clearText: const <String, Object?>{'amount': 42},
      key: key,
      associatedData: 'document-1|2026-07-17',
    );
    final tampered = Map<String, dynamic>.from(envelope);
    tampered['ciphertext'] = '${tampered['ciphertext']}A';

    expect(
      () => cipher.decryptMap(
        envelope: tampered,
        key: key,
        associatedData: 'document-1|2026-07-17',
      ),
      throwsA(isA<TransactionDecryptionException>()),
    );
    expect(
      () => cipher.decryptMap(
        envelope: Map<String, dynamic>.from(envelope),
        key: key,
        associatedData: 'document-1|2026-07-18',
      ),
      throwsA(isA<TransactionDecryptionException>()),
    );
  });

  test('generates a random 256-bit data key', () async {
    final key = await cipher.newDataKey();

    expect(await key.extractBytes(), hasLength(32));
  });
}
