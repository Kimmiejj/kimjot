import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../app/app_language.dart';
import '../../shared/widgets/loading_screen.dart';
import '../security/transaction_encryption_gate.dart';
import '../security/transaction_encryption_manager.dart';
import '../transactions/transaction_repository.dart';
import 'auth_service.dart';
import 'auth_user.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authService,
    required this.transactionRepository,
    super.key,
  });

  final AuthService authService;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen(message: context.strings.checkingSignIn);
        }

        final user = snapshot.data;
        if (user == null) {
          if (transactionRepository case final TransactionEncryptionController controller) {
            controller.clearEncryptionKey();
          }
          return LoginScreen(authService: authService);
        }

        final appShell = AppShell(
          user: user,
          authService: authService,
          transactionRepository: transactionRepository,
        );
        if (transactionRepository case final TransactionEncryptionController controller) {
          return TransactionEncryptionGate(
            user: user,
            controller: controller,
            child: appShell,
          );
        }
        return appShell;
      },
    );
  }
}
