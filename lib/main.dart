import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/kimjod_app.dart';
import 'app/app_language.dart';
import 'features/auth/firebase_auth_service.dart';
import 'features/ai/ai_settings_store.dart';
import 'features/scan/album_sync_background_service.dart';
import 'features/transactions/firebase_transaction_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseInitialization = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7F5EF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final initialLanguage = await AppLanguageController.loadSavedLanguage();

  runApp(
    KimjodApp(
      firebaseInitialization: firebaseInitialization,
      authService: FirebaseAuthService(),
      transactionRepository: FirebaseTransactionRepository(),
      initialLanguage: initialLanguage,
    ),
  );

  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  try {
    await Future.wait<void>([
      AiSettingsStore.instance.load(),
      AlbumSyncBackgroundService.initialize(),
    ]);
  } catch (_) {
    // Optional services retry when their features are opened. They must not
    // delay the first frame or prevent the core transaction flow from loading.
  }
}
