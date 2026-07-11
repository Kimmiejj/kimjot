import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/kimjod_app.dart';
import 'features/auth/firebase_auth_service.dart';
import 'features/transactions/firebase_transaction_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    KimjodApp(
      firebaseInitialization: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      authService: FirebaseAuthService(),
      transactionRepository: FirebaseTransactionRepository(),
    ),
  );
}
