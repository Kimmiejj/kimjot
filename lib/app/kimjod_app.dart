import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/auth_service.dart';
import '../features/transactions/transaction_repository.dart';
import 'app_language.dart';
import 'firebase_bootstrap.dart';

class KimjodApp extends StatefulWidget {
  const KimjodApp({
    required this.firebaseInitialization,
    required this.authService,
    required this.transactionRepository,
    this.initialLanguage = AppLanguage.en,
    super.key,
  });

  final Future<FirebaseApp> firebaseInitialization;
  final AuthService authService;
  final TransactionRepository transactionRepository;
  final AppLanguage initialLanguage;

  @override
  State<KimjodApp> createState() => _KimjodAppState();
}

class _KimjodAppState extends State<KimjodApp> {
  late final AppLanguageController _languageController;

  @override
  void initState() {
    super.initState();
    _languageController = AppLanguageController(
      initialLanguage: widget.initialLanguage,
    );
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildTheme();

    return AppLanguageScope(
      controller: _languageController,
      child: AnimatedBuilder(
        animation: _languageController,
        builder: (context, _) {
          return MaterialApp(
            title: 'kimjod',
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: _languageController.locale,
            supportedLocales: AppLanguage.values
                .map((language) => language.locale)
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: FirebaseBootstrap(
              firebaseInitialization: widget.firebaseInitialization,
              authService: widget.authService,
              transactionRepository: widget.transactionRepository,
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF1FC9DC);
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      fontFamily: 'Itim',
      useMaterial3: true,
    );

    return baseTheme;
  }
}
