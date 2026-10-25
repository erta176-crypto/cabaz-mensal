/// Modelos do domínio. Espelham as tabelas do Postgres (colunas em pt-PT).
/// Os mapas `toMap`/`fromMap` usam os nomes das colunas.
library;

enum Unidade {
  un('un', 'Unidade'),
  kg('kg', 'Quilo (ao peso)');

  const Unidade(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static Unidade deCodigo(String codigo) => switch (codigo) {
    'un' => Unidade.un,
    'kg' => Unidade.kg,
    _ => throw FormatException('Unidade desconhecida: $codigo'),
  };
}

class Loja {
  const Loja({
    required this.id,
    required this.slug,
    required this.nome,
    this.cadeia,
    this.local,
    this.cor,
    this.arquivada = false,
  });

  final String id;
  final String slug;
  final String nome;
  final String? cadeia;
  final String? local;
  final String? cor;

  /// Loja com compras que já não se usa (não aparece na Lista).
  final bool arquivada;

  factory Loja.fromMap(Map<String, dynamic> m) => Loja(
    id: m['id'] as String,
    slug: m['slug'] as String,
    nome: m['nome'] as String,
    cadeia: m['cadeia'] as String?,
    local: m['local'] as String?,
    cor: m['cor'] as String?,
    arquivada: m['arquivada'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'slug': slug,
    'nome': nome,
    'cadeia': cadeia,
    'local': local,
    'cor': cor,
    'arquivada': arquivada,
  };

  Loja copyWith({
    String? nome,
    String? cadeia,
    String? local,
    String? cor,
    bool? arquivada,
  }) => Loja(
    id: id,
    slug: slug,
    nome: nome ?? this.nome,
    cadeia: cadeia ?? this.cadeia,
    local: local ?? this.local,
    cor: cor ?? this.cor,
    arquivada: arquivada ?? this.arquivada,
  );
}

class Categoria {
  const Categoria({required this.id, required this.nome, required this.ordem});

  final String id;
  final String nome;
  final int ordem;

  factory Categoria.fromMap(Map<String, dynamic> m) => Categoria(
    id: m['id'] as String,
    nome: m['nome'] as String,
    ordem: (m['ordem'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'ordem': ordem};

  Categoria copyWith({String? nome, int? ordem}) =>
      Categoria(id: id, nome: nome ?? this.nome, ordem: ordem ?? this.ordem);
}

class Artigo {
  const Artigo({
    required this.id,
    required this.nome,
    required this.categoriaId,
    required this.unidade,
    this.ativo = true,
    this.ean,
  });

  final String id;
  final String nome;
  final String? categoriaId;
  final Unidade unidade;
  final bool ativo;

  /// Código de barras normalizado (ver normalizarEan), ou null.
  final String? ean;

  factory Artigo.fromMap(Map<String, dynamic> m) => Artigo(
    id: m['id'] as String,
    nome: m['nome'] as String,
    categoriaId: m['categoria_id'] as String?,
    unidade: Unidade.deCodigo(m['unidade'] as String),
    ativo: m['ativo'] as bool? ?? true,
    ean: m['ean'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'categoria_id': categoriaId,
    'unidade': unidade.codigo,
    'ativo': ativo,
    'ean': ean,
  };
}

class Alias {
  const Alias({
    required this.id,
    required this.artigoId,
    required this.lojaId,
    required this.textoTalao,
  });

  final String id;
  final String artigoId;
  final String lojaId;
  final String textoTalao;

  Map<String, dynamic> toMap() => {
    'id': id,
    'artigo_id': artigoId,
    'loja_id': lojaId,
    'texto_talao': textoTalao,
  };
}

enum OrigemPreco { talao, manual, lista }

class RegistoPreco {
  const RegistoPreco({
    required this.id,
    required this.artigoId,
    required this.lojaId,
    required this.data,
    required this.precoCent,
    required this.origem,
  });

  final String id;
  final String artigoId;
  final String lojaId;
  final DateTime data;
  final int precoCent;
  final OrigemPreco origem;

  factory RegistoPreco.fromMap(Map<String, dynamic> m) => RegistoPreco(
    id: m['id'] as String,
    artigoId: m['artigo_id'] as String,
    lojaId: m['loja_id'] as String,
    data: DateTime.parse(m['data'] as String),
    precoCent: (m['preco_cent'] as num).toInt(),
    origem: OrigemPreco.values.byName(m['origem'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'artigo_id': artigoId,
    'loja_id': lojaId,
    'data': dataIso(data),
    'preco_cent': precoCent,
    'origem': origem.name,
  };
}

/// De onde vem o preço atual: registado por mim ou pesquisado online (P1).
enum FontePreco { registado, online }

/// Preço mais recente de um artigo numa loja (view precos_atuais).
class PrecoAtual {
  const PrecoAtual({
    required this.artigoId,
    required this.lojaId,
    required this.precoCent,
    required this.data,
    this.fonte = FontePreco.registado,
    this.desatualizado = false,
  });

  final String artigoId;
  final String lojaId;
  final int precoCent;
  final DateTime data;
  final FontePreco fonte;

  /// Preço online fora da validade. Os registados nunca ficam desatualizados.
  final bool desatualizado;

  factory PrecoAtual.fromMap(Map<String, dynamic> m) => PrecoAtual(
    artigoId: m['artigo_id'] as String,
    lojaId: m['loja_id'] as String,
    precoCent: (m['preco_cent'] as num).toInt(),
    data: DateTime.parse(m['data'] as String),
  );
}

class ItemLista {
  const ItemLista({
    required this.id,
    required this.lojaId,
    required this.artigoId,
    required this.qtdPadrao,
    required this.incluido,
    num? qtd,
    this.comprado = false,
    this.ordem = 0,
  }) : qtd = qtd ?? qtdPadrao;

  /// Na cache local pode ainda não existir (linha criada sem rede): a
  /// identidade de um item é (loja, artigo).
  final String? id;
  final String lojaId;
  final String artigoId;

  /// Quantidade habitual: unidades ou quilos (ex.: 1.3 kg).
  final num qtdPadrao;

  /// Quantidade desta compra.
  final num qtd;
  final bool incluido;
  final bool comprado;
  final int ordem;

  factory ItemLista.fromMap(Map<String, dynamic> m) => ItemLista(
    id: m['id'] as String?,
    lojaId: m['loja_id'] as String,
    artigoId: m['artigo_id'] as String,
    qtdPadrao: _numero(m['qtd_padrao']) ?? 1,
    qtd: _numero(m['qtd']),
    incluido: m['incluido'] as bool? ?? true,
    comprado: m['comprado'] as bool? ?? false,
    ordem: (m['ordem'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': ?id,
    'loja_id': lojaId,
    'artigo_id': artigoId,
    'qtd_padrao': qtdPadrao,
    'qtd': qtd,
    'incluido': incluido,
    'comprado': comprado,
    'ordem': ordem,
  };

  ItemLista copyWith({
    num? qtdPadrao,
    num? qtd,
    bool? incluido,
    bool? comprado,
  }) => ItemLista(
    id: id,
    lojaId: lojaId,
    artigoId: artigoId,
    qtdPadrao: qtdPadrao ?? this.qtdPadrao,
    qtd: qtd ?? this.qtd,
    incluido: incluido ?? this.incluido,
    comprado: comprado ?? this.comprado,
    ordem: ordem,
  );
}

/// O PostgREST devolve numeric como número; a cache pode guardar texto.
num? _numero(Object? v) => switch (v) {
  num n => n,
  String s => num.tryParse(s),
  _ => null,
};

enum OrigemCompra { manual, talao, importacao, lista }

class Compra {
  const Compra({
    required this.id,
    required this.lojaId,
    required this.local,
    required this.data,
    required this.totalCent,
    required this.poupancaCent,
    required this.origem,
    required this.ficheiro,
    required this.rever,
  });

  final String id;
  final String lojaId;
  final String? local;
  final DateTime data;
  final int totalCent;
  final int poupancaCent;
  final OrigemCompra origem;
  final String? ficheiro;
  final bool rever;

  Map<String, dynamic> toMap() => {
    'id': id,
    'loja_id': lojaId,
    'local': local,
    'data': dataIso(data),
    'total_cent': totalCent,
    'poupanca_cent': poupancaCent,
    'origem': origem.name,
    'ficheiro': ficheiro,
    'rever': rever,
  };
}

class LinhaCompra {
  const LinhaCompra({
    required this.id,
    required this.compraId,
    required this.artigoId,
    required this.textoOriginal,
    required this.quantidade,
    required this.pesoG,
    required this.precoUnitCent,
    required this.brutoCent,
    required this.descontoCent,
    required this.pagoCent,
  });

  final String id;
  final String compraId;
  final String? artigoId;
  final String? textoOriginal;
  final int? quantidade;
  final int? pesoG;
  final int? precoUnitCent;
  final int brutoCent;
  final int descontoCent;
  final int pagoCent;

  factory LinhaCompra.fromMap(Map<String, dynamic> m) => LinhaCompra(
    id: m['id'] as String,
    compraId: m['compra_id'] as String,
    artigoId: m['artigo_id'] as String?,
    textoOriginal: m['texto_original'] as String?,
    quantidade: (m['quantidade'] as num?)?.toInt(),
    pesoG: (m['peso_g'] as num?)?.toInt(),
    precoUnitCent: (m['preco_unit_cent'] as num?)?.toInt(),
    brutoCent: (m['bruto_cent'] as num).toInt(),
    descontoCent: (m['desconto_cent'] as num).toInt(),
    pagoCent: (m['pago_cent'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'compra_id': compraId,
    'artigo_id': artigoId,
    'texto_original': textoOriginal,
    'quantidade': quantidade,
    'peso_g': pesoG,
    'preco_unit_cent': precoUnitCent,
    'bruto_cent': brutoCent,
    'desconto_cent': descontoCent,
    'pago_cent': pagoCent,
  };
}

/// Linha da view resumo_por_loja.
class ResumoLoja {
  const ResumoLoja({
    required this.lojaId,
    required this.slug,
    required this.nome,
    required this.nCompras,
    required this.totalCent,
  });

  final String lojaId;
  final String slug;
  final String nome;
  final int nCompras;
  final int totalCent;

  factory ResumoLoja.fromMap(Map<String, dynamic> m) => ResumoLoja(
    lojaId: m['loja_id'] as String,
    slug: m['slug'] as String,
    nome: m['nome'] as String,
    nCompras: (m['n_compras'] as num).toInt(),
    totalCent: (m['total_cent'] as num).toInt(),
  );
}

/// Data no formato AAAA-MM-DD (coluna date do Postgres).
String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
