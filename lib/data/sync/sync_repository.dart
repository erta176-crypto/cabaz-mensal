import 'dart:async';
import 'dart:convert';

import '../local/base_local.dart';
import '../repositorios.dart';
import 'sincronizador.dart';

class LocalSyncRepository implements SyncRepository {
  LocalSyncRepository(this._base, this._sincronizador);

  final BaseLocal _base;
  final Sincronizador? _sincronizador;

  @override
  Stream<EstadoSync> observarEstado() =>
      _sincronizador?.estado ?? Stream.value(const EstadoSync());

  @override
  Stream<List<AlteracaoPendente>> observarPendentes() =>
      _base.observarPendentes().map(
        (l) => [
          for (final p in l)
            AlteracaoPendente(
              id: p.id,
              descricao: descreverOperacao(p),
              tentativas: p.tentativas,
              erro: p.erro,
            ),
        ],
      );

  @override
  Future<void> sincronizar() async => _sincronizador?.sincronizar();

  @override
  Future<void> descartar(int id) async {
    final p = (await _base.observarPendentes().first)
        .where((p) => p.id == id)
        .firstOrNull;
    if (p == null) return;
    final s = _sincronizador;
    if (s != null) {
      await s.descartar(p);
    } else {
      await _base.removerPendente(id);
    }
  }

  @override
  Future<void> recarregarTudo({bool descartarPendentes = false}) async {
    if (descartarPendentes) await _base.delete(_base.pendentes).go();
    await _sincronizador?.recarregarTudo();
  }

  @override
  Future<void> limparLocal() => _base.limparTudo();
}

/// Texto curto para a lista de alterações pendentes.
String descreverOperacao(Pendente p) {
  const nomes = {
    'lojas': 'loja',
    'categorias': 'categoria',
    'artigos': 'artigo',
    'aliases': 'alias',
    'itens_lista': 'item da lista',
    'registos_preco': 'preço',
    'preferencias': 'preferências',
  };
  if (p.operacao == 'rpc') {
    return p.alvo == 'concluir_compra' ? 'Compra concluída' : p.alvo;
  }
  final alvo = nomes[p.alvo] ?? p.alvo;
  final payload = jsonDecode(p.payload) as Map;
  final campos = (payload['campos'] as Map?) ?? const {};
  if (p.operacao == 'atualizar' && campos.containsKey('apagado_em')) {
    return campos['apagado_em'] == null
        ? 'Repor $alvo'
        : 'Eliminar $alvo';
  }
  final linha = (payload['linha'] as Map?) ?? const {};
  final nome = linha['nome'];
  return p.operacao == 'inserir'
      ? 'Guardar $alvo${nome == null ? '' : ' «$nome»'}'
      : 'Alterar $alvo';
}
