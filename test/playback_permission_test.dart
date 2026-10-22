import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';

void main() {
  test('unprotected beta permits playback but a protected account starts denied', () {
    final permission = PlaybackPermission();
    final betaPermit = permission.acquire();
    final owner = permission.protect();
    expect(betaPermit.ensureValid, throwsStateError);
    expect(permission.acquire, throwsStateError);
    expect(permission.grant(owner), isTrue);
    permission.acquire().ensureValid();
  });

  test('revocation cancels in-flight work even after the account is allowed again', () {
    final permission = PlaybackPermission();
    final owner = permission.protect();
    permission.grant(owner);
    final pendingLoad = permission.acquire();
    permission.revoke(owner);
    expect(pendingLoad.ensureValid, throwsStateError);
    permission.grant(owner);
    expect(pendingLoad.ensureValid, throwsStateError);
    permission.acquire().ensureValid();
  });

  test('old account cannot grant or revoke the replacement account', () {
    final permission = PlaybackPermission();
    final old = permission.protect();
    permission.grant(old);
    final oldPermit = permission.acquire();
    final next = permission.protect();
    expect(permission.grant(old), isFalse);
    expect(permission.acquire, throwsStateError);
    permission.grant(next);
    final current = permission.acquire();
    expect(permission.revoke(old), isFalse);
    current.ensureValid();
    expect(oldPermit.ensureValid, throwsStateError);
  });
}
