class AuthAccount {
  final String uid;
  final String? displayName;
  const AuthAccount({required this.uid, this.displayName});
}

enum LoginProvider { google, apple }

class LoginFailure implements Exception {
  final String message;
  final bool cancelled;
  const LoginFailure(this.message, {this.cancelled = false});
}

abstract class AuthRepository {
  Future<void> initialize();
  Stream<AuthAccount?> get accountChanges;
  bool supports(LoginProvider provider);
  Future<void> signIn(LoginProvider provider);
  Future<void> signOut();
  Future<void> deleteAccount();
}
