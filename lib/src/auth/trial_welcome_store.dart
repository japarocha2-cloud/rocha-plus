import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per account UID, that the "7 dias grátis" welcome was presented.
///
/// Presentation only: the trial itself is owned and dated by the server, so
/// this flag can never grant, extend or restart a trial.
class TrialWelcomeStore {
  static const _prefix = 'rocha.trialWelcomeShown.';

  final Future<SharedPreferences> Function() _prefs;

  TrialWelcomeStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static String keyFor(String uid) => '$_prefix$uid';

  Future<bool> wasShown(String uid) async {
    try {
      return (await _prefs()).getBool(keyFor(uid)) ?? false;
    } catch (_) {
      // Unknown storage state: do not nag the user with a repeated welcome.
      return true;
    }
  }

  Future<void> markShown(String uid) async {
    try {
      await (await _prefs()).setBool(keyFor(uid), true);
    } catch (_) {}
  }
}
