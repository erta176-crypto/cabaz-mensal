import 'package:cabaz_mensal/core/desbloqueio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  test('cancelar não é erro: fica bloqueado sem mensagem', () {
    for (final c in [
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.systemCanceled,
      LocalAuthExceptionCode.timeout,
    ]) {
      expect(semDesbloqueio(c), isFalse, reason: c.name);
    }
  });

  test('demasiadas tentativas e sem bloqueio de ecrã: mensagem própria', () {
    String mensagem(LocalAuthExceptionCode c) {
      try {
        semDesbloqueio(c);
      } on ErroDesbloqueio catch (e) {
        return e.mensagem;
      }
      fail('devia lançar ErroDesbloqueio');
    }

    expect(
      mensagem(LocalAuthExceptionCode.temporaryLockout),
      contains('Demasiadas tentativas'),
    );
    expect(
      mensagem(LocalAuthExceptionCode.biometricLockout),
      contains('Demasiadas tentativas'),
    );
    expect(
      mensagem(LocalAuthExceptionCode.noCredentialsSet),
      contains('não tem bloqueio de ecrã'),
    );
    expect(
      mensagem(LocalAuthExceptionCode.deviceError),
      contains('deviceError'),
    );
  });
}
