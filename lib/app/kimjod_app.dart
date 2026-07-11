import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_service.dart';
import '../features/transactions/transaction_repository.dart';
import 'firebase_bootstrap.dart';

class KimjodApp extends StatelessWidget {
  const KimjodApp({
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
    const seedColor = Color(0xFF1FC9DC);

    return MaterialApp(
      title: 'kimjod',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: FirebaseBootstrap(
        firebaseInitialization: firebaseInitialization,
        authService: authService,
        transactionRepository: transactionRepository,
      ),
    );
  }
}
