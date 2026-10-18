class CastReadiness {
  static Future<bool> ready = Future<bool>.value(false);
  static void initialize(Future<bool> Function() configure) {
    ready = _configure(configure);
  }

  static Future<bool> _configure(Future<bool> Function() configure) async {
    try {
      return await configure().timeout(const Duration(seconds: 8));
    } catch (_) {
      return false;
    }
  }
}
