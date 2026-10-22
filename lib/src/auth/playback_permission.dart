/// A revocable local permit. It is never evidence of a paid subscription.
class PlaybackPermission {
  static final instance = PlaybackPermission();
  Object? _owner;
  bool _allowed = true;
  int _revision = 0;

  Object protect() {
    final owner = Object();
    _owner = owner;
    _allowed = false;
    _revision++;
    return owner;
  }

  bool grant(Object owner) {
    if (!identical(owner, _owner)) return false;
    _allowed = true;
    return true;
  }

  bool revoke(Object owner) {
    if (!identical(owner, _owner)) return false;
    _allowed = false;
    _revision++;
    return true;
  }

  PlaybackPermit acquire() {
    if (!_allowed) throw StateError('Acesso à reprodução não autorizado.');
    return PlaybackPermit._(this, _revision);
  }
}

class PlaybackPermit {
  PlaybackPermit._(this._permission, this._revision);
  final PlaybackPermission _permission;
  final int _revision;

  void ensureValid() {
    if (!_permission._allowed || _permission._revision != _revision) {
      throw StateError('A autorização de reprodução expirou.');
    }
  }
}
