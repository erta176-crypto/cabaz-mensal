import '../local/base_local.dart';

/// Escreve na cache local e põe a operação na fila, numa só transação.
/// Os repositórios locais só escrevem através desta classe.
class Escrita {
  Escrita(this.base, {this.aposEscrever});

  final BaseLocal base;

  /// Chamado depois de cada escrita (o sincronizador tenta enviar logo).
  void Function()? aposEscrever;

  /// Cria (ou reativa) uma linha. Envia SEMPRE a linha completa, com
  /// apagado_em = null, para o upsert não falhar em colunas obrigatórias.
  Future<void> inserir(String tabela, Map<String, dynamic> linha) async {
    final temApagado = tabela != 'preferencias';
    final paraEnviar = {...linha, if (temApagado) 'apagado_em': null};
    if (!enviaId(tabela)) paraEnviar.remove('id');
    for (final c in [
      'user_id',
      'atualizado_em',
      'criado_em',
      'reiniciado_em',
    ]) {
      paraEnviar.remove(c);
    }
    await base.transaction(() async {
      // Mantém na cache o que só o servidor conhece (id, reiniciado_em…).
      final atual = await base.lerLinha(tabela, chaveDe(tabela, linha));
      final completa = {
        ...?atual,
        ...linha,
        if (temApagado) 'apagado_em': null,
      };
      await base.gravarLinha(tabela, completa);
      await base.enfileirar(
        operacao: 'inserir',
        alvo: tabela,
        chaves: ['$tabela:${chaveDe(tabela, completa)}'],
        payload: {'linha': paraEnviar, 'on_conflict': onConflictDe(tabela)},
      );
    });
    aposEscrever?.call();
  }

  /// Edição: só os [campos] alterados (upsert parcial = UPDATE).
  Future<void> atualizar(
    String tabela,
    String chave,
    Map<String, dynamic> campos,
  ) async {
    await base.transaction(() async {
      final atual = await base.lerLinha(tabela, chave);
      if (atual == null) {
        throw StateError('Linha $tabela:$chave não existe na cache.');
      }
      await base.gravarLinha(tabela, {...atual, ...campos});
      await base.enfileirar(
        operacao: 'atualizar',
        alvo: tabela,
        chaves: ['$tabela:$chave'],
        payload: {'filtro': filtroDe(tabela, atual), 'campos': campos},
      );
    });
    aposEscrever?.call();
  }

  /// Eliminar = marcar apagado_em (propaga-se aos outros dispositivos).
  Future<void> apagar(String tabela, String chave) => atualizar(tabela, chave, {
    'apagado_em': DateTime.now().toUtc().toIso8601String(),
  });

  /// "Anular" uma eliminação.
  Future<void> restaurar(String tabela, String chave) =>
      atualizar(tabela, chave, {'apagado_em': null});

  /// Chamada a uma função do servidor (ex.: concluir_compra). [efeitos]
  /// aplica na cache o que a função fará no servidor; [chaves] protege essas
  /// linhas de serem substituídas por dados antigos até a função ser enviada.
  Future<void> rpc(
    String nome,
    Map<String, dynamic> params, {
    required List<String> chaves,
    required Future<void> Function() efeitos,
  }) async {
    await base.transaction(() async {
      await efeitos();
      await base.enfileirar(
        operacao: 'rpc',
        alvo: nome,
        chaves: chaves,
        payload: params,
      );
    });
    aposEscrever?.call();
  }
}
