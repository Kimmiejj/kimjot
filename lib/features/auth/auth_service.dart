import 'auth_user.dart';

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();

  Future<void> signInWithGoogle();

  Future<void> deleteAccount();

  Future<void> signOut();
}
