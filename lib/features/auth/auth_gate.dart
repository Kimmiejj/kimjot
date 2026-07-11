import 'package:flutter/material.dart';

import '../../shared/widgets/loading_screen.dart';
import '../home/home_screen.dart';
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
          return const LoadingScreen(message: 'Checking sign in...');
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: authService);
        }

        return HomeScreen(
          user: user,
          authService: authService,
          transactionRepository: transactionRepository,
        );
      },
    );
  }
}
