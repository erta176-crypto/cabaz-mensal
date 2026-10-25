import 'dart:convert';

import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../local/base_local.dart';
import '../repositorios.dart';
import 'base.dart';

/// Chamada a uma RPC: nome e parâmetros → resposta crua. Injetável nos testes.
typedef ChamarRpc = Future<dynamic> Function(
  String nome,
  Map<String, dynamic> params,
);

/// Leitura das linhas de uma compra. Injetável nos testes.
typedef LerLinhas = Future<List<Map<String, dynamic>>> Function(
  String compraId,
);

const _semRedeHistorico = 'Sem rede: o histórico precisa do servidor.';

/// Painel (com cache do último resultado) e histórico (só com rede).
class SupabaseEstatisticasRepository implements EstatisticasRepository {
  SupabaseEstatisticasRepository({
    required this._rpc,
    required this._lerLinhas,
    required this._base,
  });

  final ChamarRpc _rpc;
  final LerLinhas _lerLinhas;
  final BaseLocal _base;

  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) async {
    final i = intervaloDe(filtro.periodo, hoje ?? DateTime.now());
    final de = dataIso(i.de);
    final ate = dataIso(i.ate);
    final chave = 'painel:${filtro.periodo.name}:${filtro.lojaId ?? 'todas'}';
    final dynamic resposta;
    try {
      resposta = await comErrosTraduzidos(
        () =>
            _rpc('painel', {'p_de': de, 'p_ate': ate, 'p_loja': filtro.lojaId}),
      );
    } on ErroDados {
      rethrow;
    } catch (_) {
      return _daCache(chave, de, ate);
    }
    final dados = DadosPainel.fromJson(
      (resposta as Map).cast<String, dynamic>(),
    );
    await _base.gravarEstado(
      chave,
      jsonEncode({
        'de': de,
        'ate': ate,
        'guardado_em': DateTime.now().toUtc().toIso8601String(),
        'dados': dados.toJson(),
      }),
    );
    return ResultadoPainel(dados);
  }

  /// Último resultado guardado, só se for do mesmo intervalo.
  Future<ResultadoPainel> _daCache(String chave, String de, String ate) async {
    final texto = await _base.lerEstado(chave);
    if (texto != null) {
      final c = (jsonDecode(texto) as Map).cast<String, dynamic>();
      if (c['de'] == de && c['ate'] == ate) {
        return ResultadoPainel(
          DadosPainel.fromJson((c['dados'] as Map).cast<String, dynamic>()),
          guardadoEm: DateTime.parse(c['guardado_em'] as String).toLocal(),
        );
      }
    }
    throw const ErroDados('Sem rede e sem dados guardados para este filtro.');
  }

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) async {
    final i = intervaloDe(filtro.periodo, hoje ?? DateTime.now());
    final resposta = await _comRede(
      () => _rpc('historico_compras', {
        'p_de': dataIso(i.de),
        'p_ate': dataIso(i.ate),
        'p_loja': filtro.lojaId,
        'p_artigos': artigoIds == null || artigoIds.isEmpty ? null : artigoIds,
        'p_texto': texto == null || texto.isEmpty ? null : texto,
      }),
    );
    return [
      for (final m in resposta as List)
        CompraResumo.fromMap((m as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async => [
    for (final m in await _comRede(() => _lerLinhas(compraId)))
      LinhaCompra.fromMap(m),
  ];

  Future<T> _comRede<T>(Future<T> Function() f) async {
    try {
      return await comErrosTraduzidos(f);
    } on ErroDados {
      rethrow;
    } catch (_) {
      throw const ErroDados(_semRedeHistorico);
    }
  }
}
