import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import '../features/auth/auth_service.dart';
import '../features/transactions/transaction_repository.dart';
import '../shared/widgets/loading_screen.dart';
import '../shared/widgets/setup_required_screen.dart';

class FirebaseBootstrap extends StatelessWidget {
  const FirebaseBootstrap({
    required this.firebaseInitialization,
    required this.authService,
    required this.transactionRepository,
    super.key,
  });

  final Future<FirebaseApp> firebaseInitialization;
  final AuthService authService;
  final TransactionRepository transactionRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SetupRequiredScreen(error: snapshot.error.toString());
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen(message: 'Starting kimjod...');
        }

        return AuthGate(
          authService: authService,
          transactionRepository: transactionRepository,
        );
      },
    );
  }
}
