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
  });

  final String id;
  final String slug;
  final String nome;
  final String? cadeia;
  final String? local;
  final String? cor;

  factory Loja.fromMap(Map<String, dynamic> m) => Loja(
    id: m['id'] as String,
    slug: m['slug'] as String,
    nome: m['nome'] as String,
    cadeia: m['cadeia'] as String?,
    local: m['local'] as String?,
    cor: m['cor'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'slug': slug,
    'nome': nome,
    'cadeia': cadeia,
    'local': local,
    'cor': cor,
  };
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
  });

  final String id;
  final String nome;
  final String? categoriaId;
  final Unidade unidade;
  final bool ativo;

  factory Artigo.fromMap(Map<String, dynamic> m) => Artigo(
    id: m['id'] as String,
    nome: m['nome'] as String,
    categoriaId: m['categoria_id'] as String?,
    unidade: Unidade.deCodigo(m['unidade'] as String),
    ativo: m['ativo'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'categoria_id': categoriaId,
    'unidade': unidade.codigo,
    'ativo': ativo,
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'artigo_id': artigoId,
    'loja_id': lojaId,
    'data': dataIso(data),
    'preco_cent': precoCent,
    'origem': origem.name,
  };
}

/// Preço mais recente de um artigo numa loja (view precos_atuais).
class PrecoAtual {
  const PrecoAtual({
    required this.artigoId,
    required this.lojaId,
    required this.precoCent,
    required this.data,
  });

  final String artigoId;
  final String lojaId;
  final int precoCent;
  final DateTime data;

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
  });

  final String id;
  final String lojaId;
  final String artigoId;

  /// Unidades ou quilos (ex.: 1.3 kg); numeric(10,3) no Postgres.
  final num qtdPadrao;
  final bool incluido;

  Map<String, dynamic> toMap() => {
    'id': id,
    'loja_id': lojaId,
    'artigo_id': artigoId,
    'qtd_padrao': qtdPadrao,
    'incluido': incluido,
  };
}

enum OrigemCompra { manual, talao, importacao }

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
