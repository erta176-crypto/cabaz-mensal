/// Desbloqueio da app com a biometria ou o PIN do telemóvel (Fase 8, D1–D2).
/// Só no Android; a sessão do Supabase não muda.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Falha do desbloqueio que não é um cancelamento; [mensagem] para mostrar.
class ErroDesbloqueio implements Exception {
  const ErroDesbloqueio(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

abstract interface class Desbloqueio {
  /// O aparelho tem biometria ou bloqueio de ecrã que a app pode pedir.
  Future<bool> disponivel();

  /// true se desbloqueou; false se a pessoa cancelou ou falhou. Lança
  /// [ErroDesbloqueio] nos outros casos (ex.: demasiadas tentativas).
  Future<bool> pedir();
}

class DesbloqueioDoAparelho implements Desbloqueio {
  final _auth = LocalAuthentication();

  @override
  Future<bool> disponivel() async =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      await _auth.isDeviceSupported();

  @override
  Future<bool> pedir() async {
    try {
      // biometricOnly: false → o PIN, padrão ou palavra-passe do ecrã
      // também servem (D2).
      return await _auth.authenticate(
        localizedReason: 'Desbloquear o Cabaz Mensal',
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      return semDesbloqueio(e.code);
    }
  }
}

/// No local_auth 3 cancelar lança exceção: os cancelamentos dão false e o
/// resto [ErroDesbloqueio] com a mensagem em português.
@visibleForTesting
bool semDesbloqueio(LocalAuthExceptionCode codigo) {
  if (codigo
      case LocalAuthExceptionCode.userCanceled ||
          LocalAuthExceptionCode.systemCanceled ||
          LocalAuthExceptionCode.timeout ||
          LocalAuthExceptionCode.authInProgress ||
          LocalAuthExceptionCode.userRequestedFallback) {
    return false;
  }
  throw switch (codigo) {
    LocalAuthExceptionCode.temporaryLockout ||
    LocalAuthExceptionCode.biometricLockout => const ErroDesbloqueio(
      'Demasiadas tentativas. Tenta daqui a pouco ou carrega em Sair.',
    ),
    LocalAuthExceptionCode.noCredentialsSet => const ErroDesbloqueio(
      'O telemóvel não tem bloqueio de ecrã. Carrega em Sair para '
      'entrar com o email.',
    ),
    _ => ErroDesbloqueio('Não foi possível desbloquear (${codigo.name}).'),
  };
}

/// Substituído nos testes.
final desbloqueioProvider = Provider<Desbloqueio>(
  (_) => DesbloqueioDoAparelho(),
);
