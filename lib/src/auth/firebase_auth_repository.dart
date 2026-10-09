import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';
import '../live/favorites_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuth? _auth;
  static const _project = String.fromEnvironment('ROCHA_FIREBASE_PROJECT_ID');
  static const _appId = String.fromEnvironment('ROCHA_FIREBASE_APP_ID');
  static const _apiKey = String.fromEnvironment('ROCHA_FIREBASE_API_KEY');
  static const _sender = String.fromEnvironment('ROCHA_FIREBASE_SENDER_ID');
  static const _googleClient = String.fromEnvironment('ROCHA_GOOGLE_SERVER_CLIENT_ID');
  static const _appleEnabled = bool.fromEnvironment('ROCHA_APPLE_ENABLED');
  bool _googleReady = false;

  // A layout-only preview may be offered by an explicitly marked build only
  // when there is no real Firebase configuration at all.
  static bool get isConfigured =>
      [_project, _appId, _apiKey, _sender].every((value) => value.isNotEmpty);


  @override
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const LoginFailure('O login desta versão está disponível apenas no Android.');
    }
    if (!isConfigured) {
      throw const LoginFailure('O login ainda não foi ativado nesta versão. Aguarde a atualização.');
    }
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: _apiKey, appId: _appId, messagingSenderId: _sender, projectId: _project,
    ));
    _auth = FirebaseAuth.instance;
  }

  @override
  Stream<AuthAccount?> get accountChanges => _auth!.authStateChanges().map((user) {
    if (user == null || user.isAnonymous ||
        !user.providerData.any((provider) =>
          provider.providerId == 'google.com' || provider.providerId == 'apple.com')) {
      return null;
    }
    return AuthAccount(uid: user.uid, displayName: user.displayName);
  });

  @override
  bool supports(LoginProvider provider) => _auth != null &&
      (provider == LoginProvider.google ? _googleClient.isNotEmpty : _appleEnabled);

  @override
  Future<void> signIn(LoginProvider provider) async {
    if (!supports(provider)) throw const LoginFailure('Esta opção de login ainda não está disponível.');
    try {
      if (provider == LoginProvider.apple) {
        await _auth!.signInWithProvider(AppleAuthProvider());
      } else {
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize(serverClientId: _googleClient);
          _googleReady = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const LoginFailure('O Google não confirmou sua identidade. Tente novamente.');
        }
        await _auth!.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
    } on GoogleSignInException catch (failure) {
      if (failure.code == GoogleSignInExceptionCode.canceled) {
        throw const LoginFailure('', cancelled: true);
      }
      throw const LoginFailure('Não foi possível entrar com Google. Confira a conexão e tente novamente.');
    } on FirebaseAuthException catch (failure) {
      if (['web-context-cancelled', 'canceled', 'popup-closed-by-user'].contains(failure.code)) {
        throw const LoginFailure('', cancelled: true);
      }
      if (failure.code == 'account-exists-with-different-credential') {
        throw const LoginFailure('Use a opção de login utilizada anteriormente nesta conta.');
      }
      throw const LoginFailure('Não foi possível confirmar o login. Confira a conexão e tente novamente.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth?.currentUser;
    if (user == null) throw const LoginFailure('Entre na conta que deseja excluir.');
    try {
      // Delete the confirmed Firebase account, never a newly selected Google account.
      await user.delete();
    } on FirebaseAuthException catch (failure) {
      if (failure.code == 'requires-recent-login') {
        throw const LoginFailure(
          'Por segurança, saia e entre novamente na mesma conta antes de excluí-la.');
      }
      throw const LoginFailure('Não foi possível excluir a conta. Confira a conexão e tente novamente.');
    }
    // Firebase deletion is already confirmed. Local cleanup must not report
    // a failed remote deletion or leave another user's favorites visible.
    try { await FavoritesRepository().save({}); } catch (_) {
      throw const LoginFailure(
        'A conta foi excluída, mas os favoritos locais não foram apagados. Limpe os dados do Rocha+ nas configurações do Android.');
    }
    if (_googleReady) {
      try { await GoogleSignIn.instance.signOut(); } catch (_) { /* Account deleted. */ }
    }
  }

  @override
  Future<void> signOut() async {
    // Revoke local Firebase access first, even if Google cleanup fails.
    await _auth!.signOut();
    if (_googleReady) {
      try { await GoogleSignIn.instance.signOut(); } catch (_) { /* Firebase session is closed. */ }
    }
  }
}
