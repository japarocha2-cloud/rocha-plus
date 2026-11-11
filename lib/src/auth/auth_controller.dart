import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;
  AuthController(this.repository);
  StreamSubscription<AuthAccount?>? _subscription;
  AuthAccount? account;
  bool initializing = true;
  bool busy = false;
  bool ready = false;
  bool _disposed = false;
  String? error;

  bool supports(LoginProvider provider) => ready && repository.supports(provider);

  Future<void> initialize() async {
    try {
      await repository.initialize();
      if (_disposed) return;
      ready = true;
      _subscription = repository.accountChanges.listen((next) {
        if (_disposed) return;
        account = next;
        initializing = false;
        notifyListeners();
      }, onError: (Object _) {
        if (_disposed) return;
        account = null;
        ready = false;
        initializing = false;
        error = 'Não foi possível verificar sua sessão. Abra o aplicativo novamente.';
        notifyListeners();
      });
    } on LoginFailure catch (failure) {
      if (_disposed) return;
      initializing = false;
      error = failure.message;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      initializing = false;
      error = 'Não foi possível iniciar o login. Tente abrir o aplicativo novamente.';
      notifyListeners();
    }
  }

  Future<void> signIn(LoginProvider provider) async {
    if (busy || !supports(provider) || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.signIn(provider);
      // Only accountChanges can grant access; a completed popup is insufficient.
    } on LoginFailure catch (failure) {
      if (!_disposed && !failure.cancelled) error = failure.message;
    } catch (_) {
      if (!_disposed) error = 'Não foi possível entrar. Tente novamente.';
    } finally {
      if (!_disposed) { busy = false; notifyListeners(); }
    }
  }

  Future<void> signOut() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.signOut();
      if (!_disposed) account = null;
    } catch (_) {
      if (!_disposed) error = 'Não foi possível sair. Tente novamente.';
    } finally {
      if (!_disposed) { busy = false; notifyListeners(); }
    }
  }

  Future<bool> deleteAccount() async {
    if (busy || !ready || account == null || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.deleteAccount();
      if (!_disposed) account = null;
      return true;
    } on LoginFailure catch (failure) {
      if (!_disposed) error = failure.message;
      return false;
    } catch (_) {
      if (!_disposed) error = 'Não foi possível excluir a conta. Tente novamente.';
      return false;
    } finally {
      if (!_disposed) { busy = false; notifyListeners(); }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
