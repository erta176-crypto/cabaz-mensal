import 'dart:async';

import 'package:cabaz_mensal/data/sync/servidor.dart';
import 'package:uuid/uuid.dart';

/// Servidor em memória que imita o Supabase o suficiente para testar a
/// sincronização: upsert por chave (incluindo chave natural), UPDATE parcial,
/// trigger de atualizado_em, chaves únicas, concluir_compra idempotente e
/// falhas de rede.
class ServidorFalso implements ServidorSync {
  final tabelas = <String, List<Map<String, dynamic>>>{};
  var _relogio = DateTime.utc(2026, 10, 15, 12);

  /// Sem rede: todas as chamadas falham com erro transitório.
  bool online = true;

  /// Tabelas onde a escrita é recusada (simula RLS → erro permanente).
  final recusar = <String>{};

  /// Aplica a próxima escrita mas "perde a resposta" (erro transitório),
  /// como quando a rede cai a meio do pedido.
  int perderRespostas = 0;

  /// Total de linhas devolvidas por [puxar] (para medir o que é puxado).
  int linhasPuxadas = 0;

  /// Registo das chamadas, pela ordem em que chegaram.
  final chamadas = <String>[];

  final _alteracoes = StreamController<void>.broadcast();

  List<Map<String, dynamic>> t(String nome) => tabelas[nome] ??= [];

  /// Avança o relógio do servidor 1 ms (cada escrita tem um atualizado_em novo).
  DateTime tique() => _relogio = _relogio.add(const Duration(milliseconds: 1));

  /// Avança o relógio do servidor (ex.: para testar a margem de sobreposição).
  void avancar(Duration d) => _relogio = _relogio.add(d);

  void _verificar(String tabela) {
    if (!online) {
      throw const ErroSync('Sem rede', transitorio: true);
    }
    if (recusar.contains(tabela)) {
      throw const ErroSync('Sem permissão (RLS)', transitorio: false);
    }
  }

  void _depois() {
    if (perderRespostas > 0) {
      perderRespostas--;
      throw const ErroSync('Resposta perdida', transitorio: true);
    }
  }

  static const _chavesNaturais = {
    'itens_lista': ['loja_id', 'artigo_id'],
    'aliases': ['loja_id', 'texto_talao', 'artigo_id'],
  };

  void _unicos(String tabela, Map<String, dynamic> linha) {
    // Índices únicos parciais (só entre os ativos), como na migração 1A.
    final coluna = switch (tabela) {
      'categorias' => 'nome',
      'lojas' => 'slug',
      _ => null,
    };
    if (coluna == null || linha['apagado_em'] != null) return;
    final repetida = t(tabela).any(
      (o) =>
          o['id'] != linha['id'] &&
          o['apagado_em'] == null &&
          o[coluna] == linha[coluna],
    );
    if (repetida) {
      throw const ErroSync('Registo repetido (23505)', transitorio: false);
    }
  }

  @override
  Future<void> inserir(
    String tabela,
    Map<String, dynamic> linha, {
    required String onConflict,
  }) async {
    _verificar(tabela);
    chamadas.add('inserir $tabela');
    final colunas = onConflict.split(',').where((c) => c != 'user_id').toList();
    final existente = t(tabela)
        .where((o) => colunas.every((c) => o[c] == linha[c]))
        .firstOrNull;
    if (existente != null) {
      final novo = {...existente, ...linha};
      _unicos(tabela, novo);
      existente
        ..addAll(linha)
        ..['atualizado_em'] = tique().toIso8601String();
    } else {
      final nova = <String, dynamic>{
        'id': const Uuid().v4(),
        if (tabela != 'preferencias') 'apagado_em': null,
        'criado_em': tique().toIso8601String(),
        ...linha,
        'atualizado_em': tique().toIso8601String(),
      };
      if (tabela == 'itens_lista') nova['qtd'] ??= nova['qtd_padrao'];
      if (_chavesNaturais.containsKey(tabela) &&
          t(tabela).any(
            (o) => _chavesNaturais[tabela]!.every((c) => o[c] == nova[c]),
          )) {
        throw const ErroSync('Registo repetido (23505)', transitorio: false);
      }
      _unicos(tabela, nova);
      t(tabela).add(nova);
    }
    _depois();
  }

  @override
  Future<void> atualizar(
    String tabela,
    Map<String, Object?> filtro,
    Map<String, dynamic> campos,
  ) async {
    _verificar(tabela);
    chamadas.add('atualizar $tabela');
    for (final o in t(tabela)) {
      if (filtro.entries.every((f) => o[f.key] == f.value)) {
        _unicos(tabela, {...o, ...campos});
        o
          ..addAll(campos)
          ..['atualizado_em'] = tique().toIso8601String();
      }
    }
    _depois();
  }

  @override
  Future<void> rpc(String nome, Map<String, dynamic> params) async {
    _verificar(nome);
    chamadas.add('rpc $nome');
    if (nome != 'concluir_compra') throw UnimplementedError(nome);
    final p = (params['payload'] as Map).cast<String, dynamic>();
    final c = (p['compra'] as Map).cast<String, dynamic>();
    if (t('compras').any((o) => o['id'] == c['id'])) {
      _depois();
      return; // idempotente
    }
    t('compras').add({...c, 'origem': 'lista'});
    for (final l in p['linhas'] as List) {
      t('linhas_compra').add({...(l as Map), 'compra_id': c['id']});
    }
    for (final r in p['precos'] as List) {
      t('registos_preco').add({
        ...(r as Map).cast<String, dynamic>(),
        'origem': 'manual',
        'apagado_em': null,
        'criado_em': tique().toIso8601String(),
        'atualizado_em': tique().toIso8601String(),
      });
    }
    for (final i in p['itens'] as List) {
      for (final o in t('itens_lista')) {
        if (o['loja_id'] == (i as Map)['loja_id'] &&
            o['artigo_id'] == i['artigo_id']) {
          o
            ..['comprado'] = false
            ..['qtd'] = o['qtd_padrao']
            ..['atualizado_em'] = tique().toIso8601String();
        }
      }
    }
    _depois();
  }

  @override
  Future<List<Map<String, dynamic>>> puxar(
    String tabela,
    DateTime? desde,
  ) async {
    if (!online) throw const ErroSync('Sem rede', transitorio: true);
    final r =
        [
          for (final o in t(tabela))
            if (desde == null ||
                DateTime.parse(o['atualizado_em'] as String).isAfter(desde))
              {...o},
        ]..sort(
          (a, b) => (a['atualizado_em'] as String).compareTo(
            b['atualizado_em'] as String,
          ),
        );
    linhasPuxadas += r.length;
    return r;
  }

  @override
  Future<DateTime> agora() async {
    if (!online) throw const ErroSync('Sem rede', transitorio: true);
    return _relogio;
  }

  @override
  Stream<void> alteracoes(List<String> tabelas) => _alteracoes.stream;

  /// Escrita feita "por outro dispositivo" diretamente no servidor.
  void escreverDireto(String tabela, Map<String, dynamic> linha) {
    final existente = t(tabela)
        .where((o) => o['id'] == linha['id'])
        .firstOrNull;
    if (existente != null) {
      existente.addAll(linha);
      existente['atualizado_em'] = tique().toIso8601String();
    } else {
      t(tabela).add({
        'apagado_em': null,
        'criado_em': tique().toIso8601String(),
        ...linha,
        'atualizado_em': tique().toIso8601String(),
      });
    }
  }
}
