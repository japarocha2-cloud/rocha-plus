import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuth? _auth;
  static const _project = String.fromEnvironment('ROCHA_FIREBASE_PROJECT_ID');
  static const _appId = String.fromEnvironment('ROCHA_FIREBASE_APP_ID');
  static const _apiKey = String.fromEnvironment('ROCHA_FIREBASE_API_KEY');
  static const _sender = String.fromEnvironment('ROCHA_FIREBASE_SENDER_ID');
  static const _googleClient = String.fromEnvironment('ROCHA_GOOGLE_SERVER_CLIENT_ID');
  static const _adminEmail = 'luquin.has.rocha2@gmail.com';
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

  // Email alone never provides administrator privileges.
  // The rochaAdmin custom claim must be issued by a trusted Firebase Admin SDK.
  @override
  Stream<AuthAccount?> get accountChanges => _auth!.idTokenChanges().asyncMap((user) async {
    if (user == null || user.isAnonymous) return null;
    final providers = user.providerData.map((provider) => provider.providerId).toSet();
    if (providers.contains('password') &&
        user.email?.toLowerCase() == _adminEmail && user.emailVerified) {
      final claims = (await user.getIdTokenResult()).claims;
      if (claims?['rochaAdmin'] == true) {
        return AuthAccount(uid: user.uid, displayName: user.displayName, isAdmin: true);
      }
      return null;
    }
    if (providers.contains('google.com') || providers.contains('apple.com')) {
      return AuthAccount(uid: user.uid, displayName: user.displayName);
    }
    return null;
  });

  @override
  bool supports(LoginProvider provider) => _auth != null &&
      (provider == LoginProvider.google ? _googleClient.isNotEmpty : false);

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
  Future<void> signInAdmin(String email, String password) async {
    if (email.trim().toLowerCase() != _adminEmail || password.isEmpty) {
      throw const LoginFailure('Credenciais administrativas inválidas.');
    }
    try {
      final result = await _auth!.signInWithEmailAndPassword(
        email: email.trim(), password: password);
      final user = result.user;
      if (user == null || !user.emailVerified ||
          (await user.getIdTokenResult(true)).claims?['rochaAdmin'] != true) {
        await _auth!.signOut();
        throw const LoginFailure('Conta ainda não autorizada como administrador.');
      }
    } on LoginFailure {
      rethrow;
    } on FirebaseAuthException {
      throw const LoginFailure('Não foi possível validar o acesso administrativo.');
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
