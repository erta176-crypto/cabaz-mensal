import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelos.dart';
import '../local/repositorios_locais.dart';
import '../repositorios.dart';
import 'base.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._c);
  final SupabaseClient _c;

  @override
  bool get temSessao => _c.auth.currentSession != null;

  @override
  String? get email => _c.auth.currentUser?.email;

  @override
  String? get utilizadorId => _c.auth.currentUser?.id;

  @override
  Stream<bool> observarSessao() =>
      _c.auth.onAuthStateChange.map((e) => e.session != null);

  @override
  Future<void> entrar({required String email, required String palavraPasse}) =>
      comErrosTraduzidos(
        () => _c.auth.signInWithPassword(email: email, password: palavraPasse),
      );

  @override
  Future<bool> criarConta({
    required String email,
    required String palavraPasse,
  }) => comErrosTraduzidos(() async {
    final r = await _c.auth.signUp(email: email, password: palavraPasse);
    return r.session != null;
  });

  @override
  Future<void> sair() => _c.auth.signOut();
}

/// Consultas sobre compras antigas (só com rede).
class SupabaseConsultasCompras implements ConsultasCompras {
  SupabaseConsultasCompras(this._c, {this.limite = limiteLeituraPadrao});
  final SupabaseClient _c;
  final Duration limite;

  @override
  Future<int> contarCompras() => _comRede(() => _c.from('compras').count());

  @override
  Future<int> comprasDaLoja(String lojaId) =>
      _comRede(() => _c.from('compras').count().eq('loja_id', lojaId));

  @override
  Future<List<String>> locaisUsados(String lojaId) => _comRede(() async {
    final linhas = await _c
        .from('compras')
        .select('local')
        .eq('loja_id', lojaId)
        .not('local', 'is', null);
    final locais = {for (final l in linhas) l['local'] as String}.toList()
      ..sort();
    return locais;
  });

  Future<T> _comRede<T>(Future<T> Function() f) => lerComRede(
    f,
    limite: limite,
    semRede: 'Sem rede: não foi possível consultar as compras no servidor.',
  );
}

class SupabaseDadosRepository implements DadosRepository {
  SupabaseDadosRepository(
    this._c, {
    this.limiteLeitura = limiteLeituraPadrao,
    this.limiteEscrita = limiteEscritaPadrao,
  });
  final SupabaseClient _c;
  final Duration limiteLeitura;
  final Duration limiteEscrita;

  Future<T> _ler<T>(Future<T> Function() f) => lerComRede(
    f,
    limite: limiteLeitura,
    semRede: 'Sem rede: não foi possível consultar o servidor.',
  );

  Future<T> _escrever<T>(Future<T> Function() f) =>
      escreverComLimite(f, limite: limiteEscrita);

  static const tabelas = [
    'lojas',
    'categorias',
    'artigos',
    'aliases',
    'compras',
    'linhas_compra',
    'registos_preco',
    'itens_lista',
  ];

  @override
  Future<bool> temDados() => _ler(() async {
    for (final t in ['lojas', 'artigos', 'compras']) {
      if (await _c.from(t).count() > 0) return true;
    }
    return false;
  });

  @override
  Future<ContagensImportacao> importar(
    Map<String, dynamic> payload, {
    required bool substituir,
  }) => _escrever(() async {
    final r = await _c.rpc(
      'importar_seed',
      params: {'payload': payload, 'substituir': substituir},
    );
    final mapa = (r as Map).cast<String, dynamic>();
    return ContagensImportacao({
      for (final MapEntry(:key, :value) in mapa.entries)
        key: (value as num).toInt(),
    });
  });

  @override
  Future<Map<String, List<Map<String, dynamic>>>> lerTudo() => _ler(() async {
    return {
      for (final t in tabelas)
        t: await buscarTudo(_c, t, limite: limiteLeitura),
    };
  });

  @override
  Future<void> apagarTudo() => _escrever(() => _c.rpc('apagar_todos_dados'));

  @override
  Future<List<ResumoLoja>> resumoPorLoja() => _ler(() async {
    final r = await _c.from('resumo_por_loja').select().order('nome');
    return r.map(ResumoLoja.fromMap).toList();
  });

  @override
  Future<ResumoDados> resumoDados() => _ler(() async {
    final lojas = await resumoPorLoja();
    return ResumoDados(
      nCompras: await _c.from('compras').count(),
      nArtigos: await _c.from('artigos').count().isFilter('apagado_em', null),
      lojas: lojas,
    );
  });

  @override
  Future<Map<String, int>> importarLote(Map<String, dynamic> payload) =>
      _escrever(() async {
        final r = await _c.rpc('importar_lote', params: {'payload': payload});
        return {
          for (final MapEntry(:key, :value) in (r as Map).entries)
            '$key': (value as num).toInt(),
        };
      });

  @override
  Future<List<({String lojaId, String data, String? local, int totalCent})>>
  comprasExistentes() => _ler(() async {
    final linhas = await buscarTudo(
      _c,
      'compras',
      colunas: 'id, loja_id, data, local, total_cent',
      limite: limiteLeitura,
    );
    return [
      for (final c in linhas)
        (
          lojaId: c['loja_id'] as String,
          data: c['data'] as String,
          local: c['local'] as String?,
          totalCent: (c['total_cent'] as num).toInt(),
        ),
    ];
  });
}
