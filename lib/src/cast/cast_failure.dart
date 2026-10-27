import 'dart:async';

enum CastFailureKind { connection, disconnected, command, receiver, superseded }

/// Public messages contain no source URL, token or native exception details.
class CastFailure extends StateError {
  final CastFailureKind kind;
  CastFailure(this.kind) : super(kind.name);
}

class CastConfirmationTimeout extends TimeoutException {
  CastConfirmationTimeout() : super('Receiver did not confirm the requested media.');
}

String castFailureMessage(Object error) {
  if (error is CastConfirmationTimeout) {
    return 'A TV conectou, mas não confirmou a reprodução deste canal. '
        'Confira a tela da TV e tente novamente.';
  }
  if (error is CastFailure) {
    return switch (error.kind) {
      CastFailureKind.connection =>
        'Não foi possível conectar à TV. Confira a rede e tente novamente.',
      CastFailureKind.disconnected =>
        'A conexão com a TV foi interrompida. Conecte novamente.',
      CastFailureKind.command =>
        'A TV não confirmou o recebimento do comando. Tente novamente.',
      CastFailureKind.receiver =>
        'A TV informou uma falha ao abrir este canal. Tente outro canal ou reprodutor.',
      CastFailureKind.superseded =>
        'A tentativa anterior foi cancelada por uma nova conexão.',
    };
  }
  return 'Não foi possível concluir a transmissão. Verifique a conexão e tente novamente.';
}
