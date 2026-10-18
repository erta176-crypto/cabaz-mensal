import 'dart:async';

import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';

/// Base de dados em memória, partilhada pelos repositórios falsos.
/// Imita a RPC importar_seed e a view resumo_por_loja.
class BaseEmMemoria {
  Map<String, List<Map<String, dynamic>>> tabelas = {};

  List<Map<String, dynamic>> t(String nome) => tabelas[nome] ?? const [];

  bool get vazia =>
      t('lojas').isEmpty && t('artigos').isEmpty && t('compras').isEmpty;
}

class FakeDadosRepository implements DadosRepository {
  FakeDadosRepository(this.base);
  final BaseEmMemoria base;

  /// Último payload recebido, para os testes inspecionarem.
  Map<String, dynamic>? ultimoPayload;

  @override
  Future<bool> temDados() async => !base.vazia;

  @override
  Future<ContagensImportacao> importar(
    Map<String, dynamic> payload, {
    required bool substituir,
  }) async {
    if (!base.vazia && !substituir) {
      throw const ErroDados('Já existem dados nesta conta.');
    }
    ultimoPayload = payload;
    base.tabelas = {
      for (final MapEntry(:key, :value) in payload.entries)
        key: [for (final m in value as List) Map<String, dynamic>.from(m as Map)],
    };
    final compras = base.t('compras');
    return ContagensImportacao({
      for (final MapEntry(:key, :value) in base.tabelas.entries)
        key: value.length,
      'compras_rever': compras.where((c) => c['rever'] == true).length,
      'total_cent': compras.fold(0, (s, c) => s + (c['total_cent'] as int)),
    });
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> lerTudo() async =>
      base.tabelas;

  @override
  Future<void> apagarTudo() async => base.tabelas = {};

  @override
  Future<List<ResumoLoja>> resumoPorLoja() async => [
    for (final l in base.t('lojas'))
      ResumoLoja(
        lojaId: l['id'] as String,
        slug: l['slug'] as String,
        nome: l['nome'] as String,
        nCompras: base.t('compras').where((c) => c['loja_id'] == l['id']).length,
        totalCent: base
            .t('compras')
            .where((c) => c['loja_id'] == l['id'])
            .fold(0, (s, c) => s + (c['total_cent'] as int)),
      ),
  ];

  @override
  Future<Map<String, int>> importarLote(Map<String, dynamic> payload) async =>
      {for (final MapEntry(:key, :value) in payload.entries) key: (value as List).length};

  @override
  Future<List<({String lojaId, String data, String? local, int totalCent})>>
  comprasExistentes() async => [
    for (final c in base.t('compras'))
      (
        lojaId: c['loja_id'] as String,
        data: c['data'] as String,
        local: c['local'] as String?,
        totalCent: c['total_cent'] as int,
      ),
  ];

  @override
  Future<ResumoDados> resumoDados() async => ResumoDados(
    nCompras: base.t('compras').length,
    nArtigos: base.t('artigos').length,
    lojas: await resumoPorLoja(),
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool comSessao = true}) : _sessao = comSessao;

  bool _sessao;
  final _eventos = StreamController<bool>.broadcast();

  @override
  bool get temSessao => _sessao;

  @override
  String? get email => _sessao ? 'teste@exemplo.pt' : null;

  @override
  String? get utilizadorId => _sessao ? 'utilizador-teste' : null;

  @override
  Stream<bool> observarSessao() => _eventos.stream;

  @override
  Future<void> entrar({
    required String email,
    required String palavraPasse,
  }) async {
    _sessao = true;
    _eventos.add(true);
  }

  @override
  Future<bool> criarConta({
    required String email,
    required String palavraPasse,
  }) async {
    await entrar(email: email, palavraPasse: palavraPasse);
    return true;
  }

  @override
  Future<void> sair() async {
    _sessao = false;
    _eventos.add(false);
  }
}
