import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../app/app_language.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/auth_service.dart';
import '../features/transactions/transaction_repository.dart';
import '../shared/widgets/loading_screen.dart';
import '../shared/widgets/setup_required_screen.dart';
import 'app_update_gate.dart';

class FirebaseBootstrap extends StatefulWidget {
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
  State<FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<FirebaseBootstrap> {
  late Future<FirebaseApp> _startup;

  @override
  void initState() {
    super.initState();
    _startup = widget.firebaseInitialization;
  }

  @override
  void didUpdateWidget(covariant FirebaseBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseInitialization != widget.firebaseInitialization) {
      _startup = widget.firebaseInitialization;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SetupRequiredScreen(error: snapshot.error.toString());
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingScreen(message: context.strings.startingKimjod);
        }

        return AppUpdateGate(
          child: AuthGate(
            authService: widget.authService,
            transactionRepository: widget.transactionRepository,
          ),
        );
      },
    );
  }
}
