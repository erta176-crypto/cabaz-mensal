import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelos.dart';
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

class SupabaseLojasRepository implements LojasRepository {
  SupabaseLojasRepository(this._c);
  final SupabaseClient _c;

  @override
  Stream<List<Loja>> observarLojas() => observarComRealtime(
    _c,
    tabelas: ['lojas'],
    carregar: () async => (await buscarTudo(
      _c,
      'lojas',
      ordem: 'nome',
    )).map(Loja.fromMap).toList(),
  );

  @override
  Future<List<ResumoLoja>> resumoPorLoja() => comErrosTraduzidos(() async {
    final r = await _c.from('resumo_por_loja').select().order('nome');
    return r.map(ResumoLoja.fromMap).toList();
  });
}

class SupabaseCategoriasRepository implements CategoriasRepository {
  SupabaseCategoriasRepository(this._c);
  final SupabaseClient _c;

  @override
  Stream<List<Categoria>> observarCategorias() => observarComRealtime(
    _c,
    tabelas: ['categorias'],
    carregar: () async => (await buscarTudo(
      _c,
      'categorias',
      ordem: 'ordem',
    )).map(Categoria.fromMap).toList(),
  );

  @override
  Future<void> criar({required String nome, required int ordem}) =>
      comErrosTraduzidos(
        () => _c.from('categorias').insert({'nome': nome, 'ordem': ordem}),
      );

  @override
  Future<void> atualizar(Categoria categoria) => comErrosTraduzidos(
    () => _c
        .from('categorias')
        .update({'nome': categoria.nome, 'ordem': categoria.ordem})
        .eq('id', categoria.id),
  );

  @override
  Future<void> eliminar(String id, {String? moverPara}) =>
      comErrosTraduzidos(() async {
        await _c
            .from('artigos')
            .update({'categoria_id': moverPara})
            .eq('categoria_id', id);
        await _c.from('categorias').delete().eq('id', id);
      });
}

class SupabaseArtigosRepository implements ArtigosRepository {
  SupabaseArtigosRepository(this._c);
  final SupabaseClient _c;

  @override
  Stream<List<Artigo>> observarArtigos() => observarComRealtime(
    _c,
    tabelas: ['artigos'],
    carregar: () async => (await buscarTudo(
      _c,
      'artigos',
      ordem: 'nome',
    )).map(Artigo.fromMap).toList(),
  );

  @override
  Stream<List<PrecoAtual>> observarPrecosAtuais() => observarComRealtime(
    _c,
    tabelas: ['registos_preco'],
    carregar: () async => (await buscarTudo(
      _c,
      'precos_atuais',
      colunas: 'artigo_id, loja_id, preco_cent, data',
      ordem: 'artigo_id',
    )).map(PrecoAtual.fromMap).toList(),
  );

  @override
  Future<void> guardar(
    Artigo artigo, {
    Map<String, int?> precosCent = const {},
    bool novo = false,
  }) => comErrosTraduzidos(() async {
    final dados = artigo.toMap();
    if (novo) {
      await _c.from('artigos').insert(dados);
    } else {
      dados.remove('id');
      await _c.from('artigos').update(dados).eq('id', artigo.id);
    }

    final atuais = {
      for (final p in await _c
          .from('precos_atuais')
          .select('loja_id, preco_cent')
          .eq('artigo_id', artigo.id))
        p['loja_id'] as String: (p['preco_cent'] as num).toInt(),
    };
    final hoje = dataIso(DateTime.now());
    final novos = [
      for (final MapEntry(key: lojaId, value: preco) in precosCent.entries)
        if (preco != null && atuais[lojaId] != preco)
          {
            'artigo_id': artigo.id,
            'loja_id': lojaId,
            'data': hoje,
            'preco_cent': preco,
            'origem': 'manual',
          },
    ];
    if (novos.isNotEmpty) await _c.from('registos_preco').insert(novos);
  });

  @override
  Future<void> eliminar(String id) =>
      comErrosTraduzidos(() => _c.from('artigos').delete().eq('id', id));
}

class SupabaseComprasRepository implements ComprasRepository {
  SupabaseComprasRepository(this._c);
  final SupabaseClient _c;

  @override
  Future<int> contarCompras() =>
      comErrosTraduzidos(() => _c.from('compras').count());
}

class SupabaseDadosRepository implements DadosRepository {
  SupabaseDadosRepository(this._c);
  final SupabaseClient _c;

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
  Future<bool> temDados() => comErrosTraduzidos(() async {
    for (final t in ['lojas', 'artigos', 'compras']) {
      if (await _c.from(t).count() > 0) return true;
    }
    return false;
  });

  @override
  Future<ContagensImportacao> importar(
    Map<String, dynamic> payload, {
    required bool substituir,
  }) => comErrosTraduzidos(() async {
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
  Future<Map<String, List<Map<String, dynamic>>>> lerTudo() =>
      comErrosTraduzidos(() async {
        return {for (final t in tabelas) t: await buscarTudo(_c, t)};
      });

  @override
  Future<void> apagarTudo() =>
      comErrosTraduzidos(() => _c.rpc('apagar_todos_dados'));
}
