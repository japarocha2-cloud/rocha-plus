import 'dart:async';

/// Only categories cross into UI/diagnostics. Native errors may contain signed
/// source URLs, so never display or persist the original error text.
enum PlaybackFailure {
  timeout,
  accessDenied,
  notFound,
  server,
  decoder,
  network,
  unknown;

  static PlaybackFailure from(Object? error) {
    if (error is TimeoutException) return timeout;
    final text = error.toString().toLowerCase();
    final status = RegExp(
      r'(?:response code|status code|http status|http error)\s*[:=]?\s*\[?(\d{3})\b',
    ).firstMatch(text)?.group(1);
    if (status == '401' || status == '403') return accessDenied;
    if (status == '404' || status == '410') return notFound;
    if (status != null && status.startsWith('5')) return server;
    if (text.contains('timed out') || text.contains('timeoutexception')) {
      return timeout;
    }
    if (text.contains('decoder') || text.contains('codecexception')) {
      return decoder;
    }
    if (text.contains('socketexception') ||
        text.contains('unknownhostexception') ||
        text.contains('connectexception')) {
      return network;
    }
    return unknown;
  }

  String get message => switch (this) {
    timeout => 'A conexão demorou demais. Tente novamente.',
    accessDenied => 'A fonte recusou o acesso a este sinal.',
    notFound => 'A fonte não encontrou este sinal.',
    server => 'O servidor do canal está temporariamente indisponível.',
    decoder => 'Não foi possível reproduzir este formato neste player.',
    network => 'Não foi possível conectar ao servidor do canal.',
    unknown => 'Este sinal está indisponível no momento.',
  };
}

/// HLS can need several sequential requests before the decoder is ready.
/// Keep the wait bounded, without rejecting a usable source after eight seconds.
Future<void> initializeLivePlayback(Future<void> Function() initialize) =>
    initialize().timeout(const Duration(seconds: 30));
