import 'dart:convert';

/// Session-scoped status from the official IFrame API, not a release certificate.
class CazeTvPlayback {
  bool ready = false;
  int? state;
  int? errorCode;

  bool get buffering => state == 3;
  String get label {
    if (errorCode != null) return errorMessage(errorCode!);
    return switch (state) {
      1 => 'Reproduzindo pelo YouTube',
      2 => 'Reprodução pausada',
      0 => 'Reprodução encerrada',
      3 => 'Carregando vídeo...',
      _ => ready ? 'Player pronto. Toque em reproduzir.' : 'Carregando player oficial...',
    };
  }

  void reset() {
    ready = false;
    state = null;
    errorCode = null;
  }

  /// Ignore malformed/stale messages after retries or navigation.
  bool accept(String message, int session) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic> || data['session'] != session) {
        return false;
      }
      if (data['event'] == 'ready') {
        ready = true;
        return true;
      }
      if (data['event'] == 'error' && data['value'] is int) {
        errorCode = data['value'] as int;
        state = null;
        return true;
      }
      final value = data['value'];
      if (data['event'] == 'state' && value is int &&
          const [-1, 0, 1, 2, 3, 5].contains(value) && errorCode == null) {
        ready = true;
        state = value;
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static String errorMessage(int code) => switch (code) {
    2 => 'O identificador do vídeo é inválido.',
    5 => 'O YouTube não conseguiu reproduzir neste dispositivo.',
    100 => 'Vídeo removido, privado ou indisponível.',
    101 || 150 => 'A CazéTV não permite incorporar este vídeo.',
    153 => 'O YouTube não reconheceu a identificação do aplicativo.',
    _ => 'Vídeo indisponível no player do YouTube (erro $code).',
  };
}
