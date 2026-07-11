class AuthUser {
  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  String get displayLabel => displayName ?? email ?? 'kimjod user';
}
