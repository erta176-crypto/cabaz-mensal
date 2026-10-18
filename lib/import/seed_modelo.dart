/// Classes do ficheiro cabaz-seed.json (formato versão 2), escritas a partir
/// da estrutura real do ficheiro. Os ids do ficheiro são inteiros (categorias,
/// artigos, compras) ou slugs (lojas); guardam-se como String para aceitar
/// também as cópias exportadas pela app, que usam UUIDs.
library;

import 'dart:convert';

class SeedLoja {
  const SeedLoja({
    required this.id,
    required this.nome,
    this.cor,
    this.cadeia,
    this.local,
  });
  final String id; // slug, ex. 'pingo-doce'
  final String nome;
  final String? cor;
  final String? cadeia;
  final String? local;
}

class SeedCategoria {
  const SeedCategoria({
    required this.id,
    required this.nome,
    required this.ordem,
  });
  final String id;
  final String nome;
  final int ordem;
}

class SeedArtigo {
  const SeedArtigo({
    required this.id,
    required this.nome,
    required this.categoriaId,
    required this.unidade,
  });
  final String id;
  final String nome;
  final String? categoriaId;
  final String unidade; // 'un' | 'kg'
}

class SeedAlias {
  const SeedAlias({
    required this.artigoId,
    required this.lojaId,
    required this.texto,
  });
  final String artigoId;
  final String lojaId;
  final String texto;
}

class SeedCompra {
  const SeedCompra({
    required this.id,
    required this.lojaId,
    required this.local,
    required this.data,
    required this.totalCent,
    required this.origem,
    required this.ficheiro,
  });
  final String id;
  final String lojaId;
  final String? local;
  final DateTime data;
  final int totalCent;
  final String origem;
  final String? ficheiro;
}

class SeedLinha {
  const SeedLinha({
    required this.compraId,
    required this.artigoId,
    required this.textoOriginal,
    required this.quantidade,
    required this.pesoKg,
    required this.brutoCent,
    required this.descontoCent,
    required this.pagoCent,
  });
  final String compraId;
  final String? artigoId;
  final String? textoOriginal;
  final int? quantidade; // null nas linhas ao peso
  final double? pesoKg; // null nas linhas à unidade
  final int brutoCent;
  final int descontoCent;
  final int pagoCent;
}

class SeedItemLista {
  const SeedItemLista({
    required this.lojaId,
    required this.artigoId,
    required this.quantidadePadrao,
    required this.incluido,
  });
  final String lojaId;
  final String artigoId;
  final num quantidadePadrao; // pode ser decimal (kg), ex. 1.3
  final bool incluido;
}

class SeedPreco {
  const SeedPreco({
    required this.artigoId,
    required this.lojaId,
    required this.data,
    required this.precoCent,
    required this.origem,
  });
  final String artigoId;
  final String lojaId;
  final DateTime data;
  final int precoCent;
  final String origem;
}

/// Totais de controlo que o ficheiro traz para verificar a importação.
class SeedControlo {
  const SeedControlo({
    required this.contagens,
    required this.totalCent,
    required this.totalPorLojaCent,
  });

  /// compras, linhas, artigos, categorias, aliases, itens_lista, precos.
  final Map<String, int> contagens;
  final int? totalCent;

  /// Por slug de loja.
  final Map<String, int> totalPorLojaCent;
}

class SeedFicheiro {
  const SeedFicheiro({
    required this.versao,
    required this.geradoEm,
    required this.moeda,
    required this.lojas,
    required this.categorias,
    required this.artigos,
    required this.aliases,
    required this.compras,
    required this.linhas,
    required this.listas,
    required this.precos,
    required this.controlo,
  });

  final int versao;
  final String? geradoEm;
  final String moeda;
  final List<SeedLoja> lojas;
  final List<SeedCategoria> categorias;
  final List<SeedArtigo> artigos;
  final List<SeedAlias> aliases;
  final List<SeedCompra> compras;
  final List<SeedLinha> linhas;
  final List<SeedItemLista> listas;
  final List<SeedPreco> precos;
  final SeedControlo? controlo;

  /// Lê e valida o texto JSON. Lança [SeedInvalido] com todos os problemas
  /// encontrados (até um limite), para mostrar de uma só vez.
  static SeedFicheiro lerTexto(String texto) {
    final Object? json;
    try {
      json = jsonDecode(texto);
    } on FormatException catch (e) {
      throw SeedInvalido(['O ficheiro não é JSON válido (${e.message}).']);
    }
    if (json is! Map<String, dynamic>) {
      throw const SeedInvalido(['O ficheiro não tem o formato esperado.']);
    }
    return _Leitor(json).ler();
  }
}

class SeedInvalido implements Exception {
  const SeedInvalido(this.erros);
  final List<String> erros;

  @override
  String toString() => 'Ficheiro inválido:\n${erros.join('\n')}';
}

/// Leitor tolerante que acumula erros em vez de parar no primeiro.
class _Leitor {
  _Leitor(this.json);
  final Map<String, dynamic> json;
  final erros = <String>[];

  void _erro(String m) {
    if (erros.length < 30) erros.add(m);
  }

  SeedFicheiro ler() {
    final versao = json['versao'];
    if (versao is! int || versao != 2) {
      _erro('Versão do ficheiro não suportada: $versao (esperada 2).');
    }
    final moeda = json['moeda'] as Object? ?? 'EUR';
    if (moeda != 'EUR') _erro('Moeda não suportada: $moeda.');

    final lojas = _lista('lojas', (m, onde) {
      return SeedLoja(
        id: _id(m, 'id', onde)!,
        nome: _texto(m, 'nome', onde)!,
        cor: _texto(m, 'cor', onde, opcional: true),
        cadeia: _texto(m, 'cadeia', onde, opcional: true),
        local: _texto(m, 'local', onde, opcional: true),
      );
    });
    final categorias = _lista('categorias', (m, onde) {
      return SeedCategoria(
        id: _id(m, 'id', onde)!,
        nome: _texto(m, 'nome', onde)!,
        ordem: _inteiro(m, 'ordem', onde) ?? 0,
      );
    });
    final artigos = _lista('artigos', (m, onde) {
      final unidade = _texto(m, 'unidade', onde)!;
      if (unidade != 'un' && unidade != 'kg') {
        _erro('$onde: unidade "$unidade" inválida (un ou kg).');
      }
      return SeedArtigo(
        id: _id(m, 'id', onde)!,
        nome: _texto(m, 'nome', onde)!,
        categoriaId: _id(m, 'categoria_id', onde, opcional: true),
        unidade: unidade,
      );
    });
    final aliases = _lista('aliases', (m, onde) {
      return SeedAlias(
        artigoId: _id(m, 'artigo_id', onde)!,
        lojaId: _id(m, 'loja_id', onde)!,
        texto: _texto(m, 'texto', onde)!,
      );
    });
    final compras = _lista('compras', (m, onde) {
      final origem = _texto(m, 'origem', onde, opcional: true) ?? 'importacao';
      if (!const ['manual', 'talao', 'importacao'].contains(origem)) {
        _erro('$onde: origem "$origem" inválida.');
      }
      return SeedCompra(
        id: _id(m, 'id', onde)!,
        lojaId: _id(m, 'loja_id', onde)!,
        local: _texto(m, 'local', onde, opcional: true),
        data: _data(m, 'data', onde),
        totalCent: _inteiro(m, 'total_cent', onde) ?? 0,
        origem: origem,
        ficheiro: _texto(m, 'ficheiro', onde, opcional: true),
      );
    });
    final linhas = _lista('linhas', (m, onde) {
      final quantidade = _inteiro(m, 'quantidade', onde, opcional: true);
      final pesoKg = _decimal(m, 'peso_kg', onde, opcional: true)?.toDouble();
      return SeedLinha(
        compraId: _id(m, 'compra_id', onde)!,
        artigoId: _id(m, 'artigo_id', onde, opcional: true),
        textoOriginal: _texto(m, 'texto_original', onde, opcional: true),
        quantidade: quantidade,
        pesoKg: pesoKg,
        brutoCent: _inteiro(m, 'bruto_cent', onde) ?? 0,
        descontoCent: _inteiro(m, 'desconto_cent', onde, opcional: true) ?? 0,
        pagoCent: _inteiro(m, 'pago_cent', onde) ?? 0,
      );
    });
    final listas = _lista('listas', (m, onde) {
      final q = _decimal(m, 'quantidade_padrao', onde) ?? 1;
      if (q <= 0) _erro('$onde: quantidade_padrao tem de ser positiva.');
      return SeedItemLista(
        lojaId: _id(m, 'loja_id', onde)!,
        artigoId: _id(m, 'artigo_id', onde)!,
        quantidadePadrao: q,
        incluido: m['incluido'] as bool? ?? true,
      );
    }, obrigatoria: false);
    final precos = _lista('precos', (m, onde) {
      final origem = _texto(m, 'origem', onde, opcional: true) ?? 'manual';
      if (!const ['talao', 'manual', 'lista'].contains(origem)) {
        _erro('$onde: origem "$origem" inválida.');
      }
      return SeedPreco(
        artigoId: _id(m, 'artigo_id', onde)!,
        lojaId: _id(m, 'loja_id', onde)!,
        data: _data(m, 'data', onde),
        precoCent: _inteiro(m, 'preco_cent', onde) ?? 0,
        origem: origem,
      );
    }, obrigatoria: false);

    final ficheiro = SeedFicheiro(
      versao: versao is int ? versao : 0,
      geradoEm: json['gerado_em'] as String?,
      moeda: '$moeda',
      lojas: lojas,
      categorias: categorias,
      artigos: artigos,
      aliases: aliases,
      compras: compras,
      linhas: linhas,
      listas: listas,
      precos: precos,
      controlo: _controlo(),
    );
    _validarReferencias(ficheiro);
    if (erros.isNotEmpty) throw SeedInvalido(List.unmodifiable(erros));
    return ficheiro;
  }

  List<T> _lista<T>(
    String chave,
    T Function(Map<String, dynamic> m, String onde) ler, {
    bool obrigatoria = true,
  }) {
    final v = json[chave];
    if (v == null && !obrigatoria) return const [];
    if (v is! List) {
      _erro('Falta a lista "$chave".');
      return const [];
    }
    final r = <T>[];
    for (var i = 0; i < v.length; i++) {
      final m = v[i];
      final onde = '$chave[$i]';
      if (m is! Map<String, dynamic>) {
        _erro('$onde não é um objeto.');
        continue;
      }
      try {
        r.add(ler(m, onde));
      } on _CampoEmFalta {
        // já registado
      }
    }
    return r;
  }

  String? _id(
    Map<String, dynamic> m,
    String k,
    String onde, {
    bool opcional = false,
  }) {
    final v = m[k];
    if (v == null) {
      if (opcional) return null;
      _erro('$onde: falta "$k".');
      throw const _CampoEmFalta();
    }
    if (v is int || (v is String && v.isNotEmpty)) return '$v';
    _erro('$onde: "$k" inválido ($v).');
    throw const _CampoEmFalta();
  }

  String? _texto(
    Map<String, dynamic> m,
    String k,
    String onde, {
    bool opcional = false,
  }) {
    final v = m[k];
    if (v is String) return v;
    if (v == null && opcional) return null;
    _erro('$onde: "$k" deve ser texto.');
    throw const _CampoEmFalta();
  }

  int? _inteiro(
    Map<String, dynamic> m,
    String k,
    String onde, {
    bool opcional = false,
  }) {
    final v = m[k];
    if (v is int) return v;
    if (v == null && opcional) return null;
    _erro('$onde: "$k" deve ser um número inteiro (cêntimos), recebido $v.');
    return null;
  }

  num? _decimal(
    Map<String, dynamic> m,
    String k,
    String onde, {
    bool opcional = false,
  }) {
    final v = m[k];
    if (v is num) return v;
    if (v == null && opcional) return null;
    _erro('$onde: "$k" deve ser um número.');
    return null;
  }

  DateTime _data(Map<String, dynamic> m, String k, String onde) {
    final v = m[k];
    final d = v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)
        ? DateTime.tryParse(v)
        : null;
    if (d == null) {
      _erro('$onde: data "$v" inválida (AAAA-MM-DD).');
      throw const _CampoEmFalta();
    }
    return d;
  }

  SeedControlo? _controlo() {
    final c = json['controlo'];
    if (c is! Map<String, dynamic>) return null;
    final porLoja = c['total_por_loja_cent'];
    return SeedControlo(
      contagens: {
        for (final MapEntry(:key, :value) in c.entries)
          if (value is int && key != 'total_cent') key: value,
      },
      totalCent: c['total_cent'] as int?,
      totalPorLojaCent: porLoja is Map<String, dynamic>
          ? {
              for (final MapEntry(:key, :value) in porLoja.entries)
                if (value is int) key: value,
            }
          : const {},
    );
  }

  void _validarReferencias(SeedFicheiro f) {
    final lojas = _unicos(f.lojas.map((l) => l.id), 'lojas');
    final categorias = _unicos(f.categorias.map((c) => c.id), 'categorias');
    final artigos = _unicos(f.artigos.map((a) => a.id), 'artigos');
    final compras = _unicos(f.compras.map((c) => c.id), 'compras');

    void ref(Set<String> conjunto, String? id, String descricao) {
      if (id != null && !conjunto.contains(id)) {
        _erro('$descricao refere "$id", que não existe.');
      }
    }

    for (final a in f.artigos) {
      ref(categorias, a.categoriaId, 'Artigo "${a.nome}"');
    }
    for (final a in f.aliases) {
      ref(artigos, a.artigoId, 'Alias "${a.texto}"');
      ref(lojas, a.lojaId, 'Alias "${a.texto}"');
    }
    for (final c in f.compras) {
      ref(lojas, c.lojaId, 'Compra ${c.id}');
    }
    for (final l in f.linhas) {
      ref(compras, l.compraId, 'Linha "${l.textoOriginal}"');
      ref(artigos, l.artigoId, 'Linha "${l.textoOriginal}"');
    }
    for (final i in f.listas) {
      ref(lojas, i.lojaId, 'Item de lista');
      ref(artigos, i.artigoId, 'Item de lista');
    }
    for (final p in f.precos) {
      ref(lojas, p.lojaId, 'Preço');
      ref(artigos, p.artigoId, 'Preço');
    }
  }

  Set<String> _unicos(Iterable<String> ids, String nome) {
    final vistos = <String>{};
    for (final id in ids) {
      if (!vistos.add(id)) _erro('Id repetido em $nome: $id.');
    }
    return vistos;
  }
}

class _CampoEmFalta implements Exception {
  const _CampoEmFalta();
}
