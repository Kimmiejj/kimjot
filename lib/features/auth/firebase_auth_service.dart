import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/app_config.dart';
import 'account_deletion_service.dart';
import 'auth_service.dart';
import 'auth_user.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({AccountDeletionService? accountDeletionService})
    : _accountDeletionService =
          accountDeletionService ?? AccountDeletionService();

  final AccountDeletionService _accountDeletionService;
  Future<void>? _googleSignInInitialization;

  @override
  Stream<AuthUser?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges().map(_toAuthUser);
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AccountDeletionException('authentication_required');
    }

    await _ensureGoogleSignInInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
    await _accountDeletionService.deleteAccount(user.uid);
  }

  @override
  Future<void> signOut() async {
    await _ensureGoogleSignInInitialized();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }
}
