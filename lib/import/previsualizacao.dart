/// Resultado da análise de um ficheiro: o estado de cada linha, o resumo e o
/// lote a enviar à RPC importar_lote (numa só transação).
library;

import '../domain/modelos.dart';
import '../domain/texto.dart';

enum EstadoLinha {
  novo('Novo'),
  atualiza('Atualiza'),
  jaExiste('Já existe'),
  erro('Erro'),
  ignorada('Ignorada');

  const EstadoLinha(this.rotulo);
  final String rotulo;
}

class LinhaPrevia {
  const LinhaPrevia({
    required this.numero,
    required this.valores,
    required this.estado,
    this.motivo,
    this.aviso,
  });

  /// Número da linha no ficheiro (1 = primeira linha de dados).
  final int numero;
  final List<String> valores;
  final EstadoLinha estado;

  /// Porquê do erro ou do "Ignorada".
  final String? motivo;

  /// Aviso que não impede a importação (ex.: possíveis talões juntos).
  final String? aviso;
}

class Previsualizacao {
  const Previsualizacao({required this.linhas, required this.lote});

  final List<LinhaPrevia> linhas;
  final LoteImportacao lote;

  int contar(EstadoLinha e) => linhas.where((l) => l.estado == e).length;

  /// Linhas que serão gravadas (novas + atualizações).
  int get aImportar => contar(EstadoLinha.novo) + contar(EstadoLinha.atualiza);

  int get comAviso => linhas.where((l) => l.aviso != null).length;

  /// "214 linhas: 180 novas, 32 atualizam, 2 com erro".
  String get resumo {
    final partes = [
      if (contar(EstadoLinha.novo) > 0) '${contar(EstadoLinha.novo)} novas',
      if (contar(EstadoLinha.atualiza) > 0)
        '${contar(EstadoLinha.atualiza)} atualizam',
      if (contar(EstadoLinha.jaExiste) > 0)
        '${contar(EstadoLinha.jaExiste)} já existem',
      if (contar(EstadoLinha.erro) > 0) '${contar(EstadoLinha.erro)} com erro',
      if (contar(EstadoLinha.ignorada) > 0)
        '${contar(EstadoLinha.ignorada)} ignoradas',
    ];
    final n = linhas.length;
    return '$n ${n == 1 ? 'linha' : 'linhas'}: ${partes.join(', ')}';
  }
}

/// O que a RPC importar_lote recebe. Os mapas usam os nomes das colunas.
class LoteImportacao {
  final categorias = <String, Map<String, dynamic>>{};
  final artigos = <String, Map<String, dynamic>>{};
  final precos = <Map<String, dynamic>>[];
  final compras = <Map<String, dynamic>>[];
  final linhas = <Map<String, dynamic>>[];

  /// Por "loja|artigo" (a chave natural da lista).
  final itens = <String, Map<String, dynamic>>{};

  bool get vazio =>
      categorias.isEmpty &&
      artigos.isEmpty &&
      precos.isEmpty &&
      compras.isEmpty &&
      itens.isEmpty;

  Map<String, dynamic> toJson() => {
    'categorias': categorias.values.toList(),
    'artigos': artigos.values.toList(),
    'precos': precos,
    'compras': compras,
    'linhas': linhas,
    'itens': itens.values.toList(),
  };
}

/// Compra já gravada, para detetar repetidas (mesma loja, data e total).
class CompraExistente {
  const CompraExistente({
    required this.lojaId,
    required this.data,
    required this.local,
    required this.totalCent,
  });

  final String lojaId;
  final DateTime data;
  final String? local;
  final int totalCent;
}

/// Tudo o que a análise precisa de saber da app (vem da cache local).
class Catalogo {
  Catalogo({
    required this.lojas,
    required this.categorias,
    required this.artigos,
    this.categoriasApagadas = const [],
    this.artigosApagados = const [],
    this.aliases = const {},
    this.precos = const [],
    this.itens = const [],
  }) {
    for (final a in artigos) {
      _artigoPorNome.putIfAbsent(normalizar(a.nome).trim(), () => a);
      for (final t in aliases[a.id] ?? const <String>[]) {
        _artigoPorNome.putIfAbsent(normalizar(t).trim(), () => a);
      }
    }
  }

  final List<Loja> lojas;
  final List<Categoria> categorias;
  final List<Artigo> artigos;
  final List<Categoria> categoriasApagadas;
  final List<Artigo> artigosApagados;
  final Map<String, List<String>> aliases;
  final List<PrecoAtual> precos;
  final List<ItemLista> itens;

  final _artigoPorNome = <String, Artigo>{};

  /// Pelo nome normalizado ou por alias (textos de talão).
  Artigo? artigo(String nome) => _artigoPorNome[normalizar(nome).trim()];

  Artigo? artigoApagado(String nome) => _porNome(artigosApagados, nome, (a) => a.nome);

  Categoria? categoria(String nome) => _porNome(categorias, nome, (c) => c.nome);

  Categoria? categoriaApagada(String nome) =>
      _porNome(categoriasApagadas, nome, (c) => c.nome);

  /// Pelo nome ou pelo slug ("Pingo Doce", "pingo-doce").
  Loja? loja(String nome) {
    final n = normalizar(nome).trim();
    return lojas
        .where((l) => normalizar(l.nome) == n || l.slug == n.replaceAll(' ', '-'))
        .firstOrNull;
  }

  int? preco(String artigoId, String lojaId) => precos
      .where((p) => p.artigoId == artigoId && p.lojaId == lojaId)
      .firstOrNull
      ?.precoCent;

  ItemLista? item(String lojaId, String artigoId) => itens
      .where((i) => i.lojaId == lojaId && i.artigoId == artigoId)
      .firstOrNull;

  int get proximaOrdem =>
      categorias.fold(0, (m, c) => c.ordem > m ? c.ordem : m) + 1;

  static T? _porNome<T>(List<T> l, String nome, String Function(T) de) {
    final n = normalizar(nome).trim();
    return l.where((x) => normalizar(de(x)).trim() == n).firstOrNull;
  }
}
