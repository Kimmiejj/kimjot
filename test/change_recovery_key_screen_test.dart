import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimjot/app/app_language.dart';
import 'package:kimjot/features/security/biometric_recovery_key_store.dart';
import 'package:kimjot/features/security/change_recovery_key_screen.dart';
import 'package:kimjot/features/security/transaction_encryption_manager.dart';

void main() {
  testWidgets('requires the current recovery key before changing it', (
    tester,
  ) async {
    final controller = _FakeController(currentKey: 'current-key-2026');
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));

    await tester.enterText(
      find.byKey(const ValueKey('current-recovery-key')),
      'wrong-current-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-recovery-key')),
      'new-private-key-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-recovery-key')),
      'new-private-key-2026',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Change recovery key'));
    await tester.pump();

    expect(find.text('The current recovery key is incorrect.'), findsOneWidget);
    expect(controller.changedTo, isNull);
  });

  testWidgets('changes the key when the current key is correct', (
    tester,
  ) async {
    final controller = _FakeController(currentKey: 'current-key-2026');
    final biometricStore = _FakeBiometricStore();
    await tester.pumpWidget(_app(controller, biometricStore));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('current-recovery-key')),
      'current-key-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-recovery-key')),
      'new-private-key-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-recovery-key')),
      'new-private-key-2026',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Change recovery key'));
    await tester.pumpAndSettle();

    expect(controller.changedTo, 'new-private-key-2026');
    expect(biometricStore.deleteRequests, 1);
    expect(find.text('Open'), findsOneWidget);
  });
}

Widget _app(
  TransactionEncryptionController controller, [
  BiometricRecoveryKeyStore? biometricKeyStore,
]) {
  return AppLanguageScope(
    controller: AppLanguageController(initialLanguage: AppLanguage.en),
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeRecoveryKeyScreen(
                  userId: 'user-123',
                  controller: controller,
                  biometricKeyStore: biometricKeyStore,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

class _FakeBiometricStore implements BiometricRecoveryKeyStore {
  int deleteRequests = 0;

  @override
  Future<String?> authenticateAndReadKey({
    required String userId,
    required bool isThai,
  }) async => null;

  @override
  Future<void> deleteKey(String userId) async {
    deleteRequests += 1;
  }

  @override
  Future<bool> hasSavedKey(String userId) async => false;

  @override
  Future<void> saveKey(String userId, String recoveryKey) async {}
}

class _FakeController implements TransactionEncryptionController {
  _FakeController({required this.currentKey});

  final String currentKey;
  String? changedTo;

  @override
  Future<bool> changeRecoveryKey({
    required String userId,
    required String currentRecoveryKey,
    required String newRecoveryKey,
  }) async {
    if (currentRecoveryKey != currentKey) return false;
    changedTo = newRecoveryKey;
    return true;
  }

  @override
  void clearEncryptionKey() {}

  @override
  Future<String> createRecoveryKey(String userId, {String? recoveryKey}) async {
    return recoveryKey ?? '';
  }

  @override
  Future<TransactionEncryptionAccess> prepareEncryption(String userId) async {
    return TransactionEncryptionAccess.unlocked;
  }

  @override
  Future<String> sendRecoveryKeyEmail(String userId) async => '';

  @override
  Future<bool> unlockWithRecoveryKey(String userId, String recoveryKey) async {
    return recoveryKey == currentKey;
  }
}
