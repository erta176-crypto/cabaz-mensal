import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/compra.dart';
import '../../domain/modelos.dart';
import '../../domain/preferencias.dart';
import '../../domain/texto.dart';
import '../repositorios.dart';
import '../sync/escrita.dart';
import 'base_local.dart';

String _agora() => DateTime.now().toUtc().toIso8601String();
String _novoId() => const Uuid().v4();

/// Slug a partir do nome ("Pingo Doce" → "pingo-doce").
String slugDe(String nome) => normalizar(
  nome,
).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

class LocalLojasRepository implements LojasRepository {
  LocalLojasRepository(this._base, this._escrita, {required this.compras});

  final BaseLocal _base;
  final Escrita _escrita;
  final Future<int> Function(String lojaId) compras;

  @override
  Stream<List<Loja>> observarLojas() => _base
      .observarTabela('lojas')
      .map((l) => l.map(Loja.fromMap).toList()..sort((a, b) => a.nome.compareTo(b.nome)));

  @override
  Future<void> guardar(Loja loja, {bool nova = false}) async {
    if (!nova) {
      await _escrita.atualizar('lojas', loja.id, {
        'nome': loja.nome,
        'cadeia': loja.cadeia,
        'local': loja.local,
        'cor': loja.cor,
      });
      return;
    }
    final slug = slugDe(loja.nome);
    if (slug.isEmpty) throw const ErroDados('Escreve um nome para a loja.');
    final todas = await _base.lerTabela('lojas', incluirApagados: true);
    final mesmoSlug = todas.where((l) => l['slug'] == slug).toList();
    if (mesmoSlug.any((l) => l['apagado_em'] == null)) {
      throw ErroDados('Já existe a loja "${loja.nome}".');
    }
    final linha = {
      ...loja.toMap(),
      // Reativa a loja eliminada com o mesmo nome (mesmo id).
      'id': mesmoSlug.isNotEmpty ? mesmoSlug.first['id'] : loja.id,
      'slug': slug,
      'arquivada': false,
    };
    await _escrita.inserir('lojas', linha);
  }

  @override
  Future<void> arquivar(String id, {required bool arquivada}) =>
      _escrita.atualizar('lojas', id, {'arquivada': arquivada});

  @override
  Future<void> eliminar(String id) async {
    final n = await compras(id);
    if (n > 0) {
      throw ErroDados(
        'Esta loja tem $n ${n == 1 ? 'compra' : 'compras'} e não pode ser '
        'eliminada. Podes arquivá-la.',
      );
    }
    final itens = await _base.lerTabela('itens_lista');
    for (final i in itens.where((i) => i['loja_id'] == id)) {
      await _escrita.apagar('itens_lista', chaveDe('itens_lista', i));
    }
    await _escrita.apagar('lojas', id);
  }
}

class LocalCategoriasRepository implements CategoriasRepository {
  LocalCategoriasRepository(this._base, this._escrita);

  final BaseLocal _base;
  final Escrita _escrita;

  @override
  Stream<List<Categoria>> observarCategorias() => _base
      .observarTabela('categorias')
      .map(
        (l) =>
            l.map(Categoria.fromMap).toList()
              ..sort((a, b) => a.ordem.compareTo(b.ordem)),
      );

  @override
  Future<void> criar({required String nome, required int ordem}) async {
    final todas = await _base.lerTabela('categorias', incluirApagados: true);
    final mesmoNome = todas.where((c) => c['nome'] == nome).toList();
    if (mesmoNome.any((c) => c['apagado_em'] == null)) {
      throw ErroDados('Já existe a categoria "$nome".');
    }
    await _escrita.inserir('categorias', {
      // Reativa a categoria eliminada com o mesmo nome.
      'id': mesmoNome.isNotEmpty ? mesmoNome.first['id'] : _novoId(),
      'nome': nome,
      'ordem': ordem,
    });
  }

  @override
  Future<void> atualizar(Categoria categoria) => _escrita.atualizar(
    'categorias',
    categoria.id,
    {'nome': categoria.nome, 'ordem': categoria.ordem},
  );

  @override
  Future<void> eliminar(String id, {String? moverPara}) async {
    for (final a in await _base.lerTabela('artigos')) {
      if (a['categoria_id'] == id) {
        await _escrita.atualizar('artigos', a['id'] as String, {
          'categoria_id': moverPara,
        });
      }
    }
    await _escrita.apagar('categorias', id);
  }

  @override
  Future<List<Categoria>> apagadas() async => [
    for (final c in await _base.lerTabela('categorias', incluirApagados: true))
      if (c['apagado_em'] != null) Categoria.fromMap(c),
  ];
}

class LocalArtigosRepository implements ArtigosRepository {
  LocalArtigosRepository(this._base, this._escrita);

  final BaseLocal _base;
  final Escrita _escrita;

  @override
  Stream<List<Artigo>> observarArtigos() => _base
      .observarTabela('artigos')
      .map(
        (l) =>
            l.map(Artigo.fromMap).toList()
              ..sort((a, b) => a.nome.compareTo(b.nome)),
      );

  @override
  Stream<List<PrecoAtual>> observarPrecosAtuais() =>
      _base.observarTabela('registos_preco').map(precosAtuaisDe);

  @override
  Stream<Map<String, List<String>>> observarAliases() =>
      _base.observarTabela('aliases').map((l) {
        final r = <String, List<String>>{};
        for (final a in l) {
          (r[a['artigo_id'] as String] ??= []).add(a['texto_talao'] as String);
        }
        return r;
      });

  @override
  Future<void> guardar(
    Artigo artigo, {
    Map<String, int?> precosCent = const {},
    bool novo = false,
  }) async {
    if (novo) {
      await _escrita.inserir('artigos', artigo.toMap());
    } else {
      final dados = artigo.toMap()..remove('id');
      await _escrita.atualizar('artigos', artigo.id, dados);
    }
    final atuais = {
      for (final p in precosAtuaisDe(await _base.lerTabela('registos_preco')))
        if (p.artigoId == artigo.id) p.lojaId: p.precoCent,
    };
    final hoje = dataIso(DateTime.now());
    for (final MapEntry(key: lojaId, value: preco) in precosCent.entries) {
      if (preco == null || atuais[lojaId] == preco) continue;
      await _escrita.inserir('registos_preco', {
        'id': _novoId(),
        'artigo_id': artigo.id,
        'loja_id': lojaId,
        'data': hoje,
        'preco_cent': preco,
        'origem': 'manual',
        'criado_em': _agora(),
      });
    }
  }

  @override
  Future<void> eliminar(String id) => _escrita.apagar('artigos', id);

  @override
  Future<List<Artigo>> apagados() async => [
    for (final a in await _base.lerTabela('artigos', incluirApagados: true))
      if (a['apagado_em'] != null) Artigo.fromMap(a),
  ];
}

/// Preço mais recente de cada artigo em cada loja (como a view precos_atuais).
List<PrecoAtual> precosAtuaisDe(List<Map<String, dynamic>> registos) {
  final melhor = <String, Map<String, dynamic>>{};
  for (final r in registos) {
    if (r['apagado_em'] != null) continue;
    final k = '${r['artigo_id']}|${r['loja_id']}';
    final atual = melhor[k];
    if (atual == null || _maisRecente(r, atual)) melhor[k] = r;
  }
  return [for (final r in melhor.values) PrecoAtual.fromMap(r)];
}

bool _maisRecente(Map<String, dynamic> a, Map<String, dynamic> b) {
  final d = (a['data'] as String).compareTo(b['data'] as String);
  if (d != 0) return d > 0;
  return ('${a['criado_em'] ?? ''}').compareTo('${b['criado_em'] ?? ''}') > 0;
}

class LocalListaRepository implements ListaRepository {
  LocalListaRepository(this._base, this._escrita);

  final BaseLocal _base;
  final Escrita _escrita;

  String _chave(ItemLista i) => '${i.lojaId}|${i.artigoId}';

  @override
  Stream<List<ItemLista>> observarItens() => _base
      .observarTabela('itens_lista')
      .map((l) => l.map(ItemLista.fromMap).toList());

  @override
  Future<void> incluir({
    required String lojaId,
    required String artigoId,
    num? qtd,
  }) async {
    final atual = await _base.lerLinha('itens_lista', '$lojaId|$artigoId');
    final padrao = (atual?['qtd_padrao'] as num?) ?? qtd ?? 1;
    // Linha completa: cria, ou reativa (incluido, comprado e apagado_em).
    await _escrita.inserir('itens_lista', {
      'loja_id': lojaId,
      'artigo_id': artigoId,
      'qtd_padrao': padrao,
      'qtd': qtd ?? padrao,
      'incluido': true,
      'comprado': false,
      'ordem': (atual?['ordem'] as num?)?.toInt() ?? 0,
    });
  }

  @override
  Future<void> marcarComprado(ItemLista item, {required bool comprado}) =>
      _escrita.atualizar('itens_lista', _chave(item), {'comprado': comprado});

  @override
  Future<void> alterarQtd(ItemLista item, num qtd) =>
      _escrita.atualizar('itens_lista', _chave(item), {'qtd': qtd});

  @override
  Future<void> alterarQtdPadrao(ItemLista item, num qtd) => _escrita.atualizar(
    'itens_lista',
    _chave(item),
    {'qtd_padrao': qtd, if (!item.comprado) 'qtd': qtd},
  );

  @override
  Future<void> definirIncluido(ItemLista item, {required bool incluido}) =>
      _escrita.atualizar('itens_lista', _chave(item), {
        'incluido': incluido,
        if (!incluido) 'comprado': false,
      });

  @override
  Future<void> repor(ItemLista anterior) =>
      _escrita.atualizar('itens_lista', _chave(anterior), {
        'incluido': anterior.incluido,
        'comprado': anterior.comprado,
        'qtd': anterior.qtd,
        'qtd_padrao': anterior.qtdPadrao,
      });
}

class LocalPreferenciasRepository implements PreferenciasRepository {
  LocalPreferenciasRepository(this._base, this._escrita);

  final BaseLocal _base;
  final Escrita _escrita;

  @override
  Stream<Preferencias> observar() =>
      _base.observarTabela('preferencias').map((l) {
        final dados = l.isEmpty ? null : l.first['dados'];
        return dados is Map
            ? Preferencias.fromJson(dados.cast<String, dynamic>())
            : const Preferencias();
      });

  @override
  Future<void> guardar(Preferencias preferencias) =>
      _escrita.inserir('preferencias', {'dados': preferencias.toJson()});
}

/// Concluir compra vai pela fila (funciona sem rede); as consultas sobre
/// compras antigas vão ao servidor através de [consultas].
class LocalComprasRepository implements ComprasRepository {
  LocalComprasRepository(this._base, this._escrita, this.consultas);

  final BaseLocal _base;
  final Escrita _escrita;
  final ConsultasCompras consultas;

  @override
  Future<int> contarCompras() => consultas.contarCompras();

  @override
  Future<int> comprasDaLoja(String lojaId) => consultas.comprasDaLoja(lojaId);

  @override
  Future<void> concluir(CompraNova compra) async {
    final payload = compra.toPayload();
    await _escrita.rpc(
      'concluir_compra',
      {'payload': payload},
      chaves: [
        for (final l in compra.linhas) ...[
          'registos_preco:${l.precoId}',
          'itens_lista:${compra.lojaId}|${l.artigoId}',
        ],
      ],
      efeitos: () async {
        final agora = _agora();
        for (final p in payload['precos'] as List) {
          await _base.gravarLinha('registos_preco', {
            ...(p as Map).cast<String, dynamic>(),
            'origem': 'manual',
            'criado_em': agora,
            'apagado_em': null,
          });
        }
        for (final l in compra.linhas) {
          final chave = '${compra.lojaId}|${l.artigoId}';
          final item = await _base.lerLinha('itens_lista', chave);
          if (item == null) continue;
          await _base.gravarLinha('itens_lista', {
            ...item,
            'comprado': false,
            'qtd': item['qtd_padrao'],
          });
        }
      },
    );
    await _lembrarLocal(compra.lojaId, compra.local);
  }

  @override
  Future<List<String>> locaisUsados(String lojaId) async {
    final chave = 'locais:$lojaId';
    try {
      final locais = await consultas.locaisUsados(lojaId);
      await _base.gravarEstado(chave, jsonEncode(locais));
      return locais;
    } catch (_) {
      final guardado = await _base.lerEstado(chave);
      return guardado == null
          ? const []
          : (jsonDecode(guardado) as List).cast<String>();
    }
  }

  Future<void> _lembrarLocal(String lojaId, String? local) async {
    if (local == null || local.isEmpty) return;
    final chave = 'locais:$lojaId';
    final guardado = await _base.lerEstado(chave);
    final locais = guardado == null
        ? <String>[]
        : (jsonDecode(guardado) as List).cast<String>();
    if (!locais.contains(local)) {
      await _base.gravarEstado(chave, jsonEncode([...locais, local]..sort()));
    }
  }
}

/// Consultas ao servidor sobre compras (não estão em cache nesta fase).
abstract interface class ConsultasCompras {
  Future<int> contarCompras();
  Future<int> comprasDaLoja(String lojaId);
  Future<List<String>> locaisUsados(String lojaId);
}
