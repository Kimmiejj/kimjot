import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/features/auth/auth_user.dart';
import 'package:kimjot/features/security/biometric_recovery_key_store.dart';
import 'package:kimjot/features/security/transaction_encryption_gate.dart';
import 'package:kimjot/features/security/transaction_encryption_manager.dart';

void main() {
  const user = AuthUser(uid: 'firebase-user-123');

  testWidgets('lets a legacy account without config set a recovery key', (
    tester,
  ) async {
    final controller = _FakeEncryptionController(
      TransactionEncryptionAccess.setupRequired,
    );
    await tester.pumpWidget(_app(user, controller));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Create a key to continue'), findsOneWidget);
    expect(find.textContaining('This account has no key yet'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('new-recovery-key')),
      'my-private-key-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-recovery-key')),
      'my-private-key-2026',
    );
    await tester.pump();
    expect(find.text('16 characters'), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('new-recovery-key')))
          .obscureText,
      isFalse,
    );
    await tester.tap(find.text('Use this key'));
    await tester.pumpAndSettle();

    expect(find.text('my-private-key-2026'), findsOneWidget);
    expect(controller.createdRecoveryKey, 'my-private-key-2026');
    expect(find.text('ENCRYPTED APP'), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('ENCRYPTED APP'), findsOneWidget);
  });

  testWidgets('rejects recovery keys that do not match', (tester) async {
    final controller = _FakeEncryptionController(
      TransactionEncryptionAccess.setupRequired,
    );
    await tester.pumpWidget(_app(user, controller));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('new-recovery-key')),
      'my-private-key-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-recovery-key')),
      'a-different-key-2026',
    );
    await tester.tap(find.text('Use this key'));
    await tester.pump();

    expect(find.text('The keys do not match.'), findsOneWidget);
    expect(controller.createdRecoveryKey, isNull);
  });

  testWidgets('unlocks an existing account with its recovery key', (
    tester,
  ) async {
    final controller = _FakeEncryptionController(
      TransactionEncryptionAccess.recoveryKeyRequired,
    );
    await tester.pumpWidget(_app(user, controller));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Encryption key required'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('unlock-recovery-key')))
          .obscureText,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      _FakeEncryptionController.recoveryKey,
    );
    await tester.pump();
    expect(find.text('48 characters'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('ENCRYPTED APP'), findsOneWidget);
  });

  testWidgets(
    'remembers a verified key and requests biometrics on next launch',
    (tester) async {
      final biometricStore = _FakeBiometricRecoveryKeyStore();
      final firstController = _FakeEncryptionController(
        TransactionEncryptionAccess.recoveryKeyRequired,
      );
      await tester.pumpWidget(_app(user, firstController, biometricStore));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('unlock-recovery-key')),
        _FakeEncryptionController.recoveryKey,
      );
      await tester.tap(find.byKey(const ValueKey('remember-recovery-key')));
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(biometricStore.savedKey, _FakeEncryptionController.recoveryKey);

      final nextController = _FakeEncryptionController(
        TransactionEncryptionAccess.recoveryKeyRequired,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_app(user, nextController, biometricStore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(biometricStore.authenticationRequests, 1);
      expect(find.text('ENCRYPTED APP'), findsOneWidget);
    },
  );

  testWidgets('recovers when unlocking after biometrics throws', (
    tester,
  ) async {
    final biometricStore = _FakeBiometricRecoveryKeyStore()
      ..savedKey = _FakeEncryptionController.recoveryKey;
    final controller = _FakeEncryptionController(
      TransactionEncryptionAccess.recoveryKeyRequired,
    )..unlockError = Exception('temporary unlock failure');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(_app(user, controller, biometricStore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Could not unlock. Try again.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('biometric-unlock')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('requests the existing key by verified email', (tester) async {
    final controller = _FakeEncryptionController(
      TransactionEncryptionAccess.recoveryKeyRequired,
    );
    await tester.pumpWidget(_app(user, controller));
    await tester.pump();

    await tester.tap(find.text('Forgot key? Send it to Google email'));
    await tester.pumpAndSettle();

    expect(controller.emailRequests, 1);
    expect(find.text('Key sent to ki***@gmail.com.'), findsOneWidget);
  });
}

Widget _app(
  AuthUser user,
  TransactionEncryptionController controller, [
  BiometricRecoveryKeyStore? biometricKeyStore,
]) {
  return AppLanguageScope(
    controller: AppLanguageController(initialLanguage: AppLanguage.en),
    child: MaterialApp(
      key: UniqueKey(),
      home: TransactionEncryptionGate(
        user: user,
        controller: controller,
        biometricKeyStore:
            biometricKeyStore ?? _FakeBiometricRecoveryKeyStore(),
        child: const Scaffold(body: Text('ENCRYPTED APP')),
      ),
    ),
  );
}

class _FakeBiometricRecoveryKeyStore implements BiometricRecoveryKeyStore {
  String? savedKey;
  int authenticationRequests = 0;

  @override
  Future<String?> authenticateAndReadKey({
    required String userId,
    required bool isThai,
  }) async {
    authenticationRequests += 1;
    return savedKey;
  }

  @override
  Future<void> deleteKey(String userId) async {
    savedKey = null;
  }

  @override
  Future<bool> hasSavedKey(String userId) async => savedKey != null;

  @override
  Future<void> saveKey(String userId, String recoveryKey) async {
    savedKey = recoveryKey;
  }
}

class _FakeEncryptionController implements TransactionEncryptionController {
  _FakeEncryptionController(this.access);

  static const recoveryKey =
      '0123-4567-89ab-cdef-0123-4567-89ab-cdef-0123-4567-89ab-cdef';

  TransactionEncryptionAccess access;
  String? createdRecoveryKey;
  Object? unlockError;
  int emailRequests = 0;

  @override
  void clearEncryptionKey() {}

  @override
  Future<String> createRecoveryKey(String userId, {String? recoveryKey}) async {
    createdRecoveryKey = recoveryKey;
    access = TransactionEncryptionAccess.unlocked;
    return recoveryKey ?? _FakeEncryptionController.recoveryKey;
  }

  @override
  Future<TransactionEncryptionAccess> prepareEncryption(String userId) async {
    return access;
  }

  @override
  Future<bool> changeRecoveryKey({
    required String userId,
    required String currentRecoveryKey,
    required String newRecoveryKey,
  }) async {
    return currentRecoveryKey == recoveryKey;
  }

  @override
  Future<String> sendRecoveryKeyEmail(String userId) async {
    emailRequests += 1;
    return 'ki***@gmail.com';
  }

  @override
  Future<bool> unlockWithRecoveryKey(
    String userId,
    String submittedRecoveryKey,
  ) async {
    if (unlockError case final error?) throw error;
    return submittedRecoveryKey == recoveryKey;
  }
}
