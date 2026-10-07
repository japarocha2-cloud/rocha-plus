class CastReadiness {
  static Future<bool> ready = Future<bool>.value(false);
  static void initialize(Future<bool> Function() configure) {
    ready = Future<bool>.sync(configure)
        .timeout(const Duration(seconds: 8))
        .catchError((Object error) => false);
  }
}
