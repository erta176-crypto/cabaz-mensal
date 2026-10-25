/// Estatísticas do Painel e dados do Histórico. Funções puras e modelos,
/// sem Flutter nem Supabase. Dinheiro sempre em cêntimos inteiros.
library;

/// Período dos filtros do Painel e do Histórico.
enum Periodo {
  esteMes('Este mês'),
  ultimos3Meses('Últimos 3 meses'),
  ultimos12Meses('Últimos 12 meses'),
  esteAno('Este ano'),
  tudo('Todo o histórico');

  const Periodo(this.rotulo);
  final String rotulo;
}

/// Datas inclusivas [de, ate] do período, a contar de [hoje] (só a data conta).
/// Os períodos em meses são de calendário: `de` é o dia 1 do primeiro mês.
({DateTime de, DateTime ate}) intervaloDe(Periodo p, DateTime hoje) {
  final ate = DateTime(hoje.year, hoje.month, hoje.day);
  final de = switch (p) {
    Periodo.esteMes => DateTime(hoje.year, hoje.month, 1),
    Periodo.ultimos3Meses => DateTime(hoje.year, hoje.month - 2, 1),
    Periodo.ultimos12Meses => DateTime(hoje.year, hoje.month - 11, 1),
    Periodo.esteAno => DateTime(hoje.year, 1, 1),
    Periodo.tudo => DateTime(2000, 1, 1),
  };
  return (de: de, ate: ate);
}

/// Filtro do painel e do histórico. Record: tem igualdade de valor (serve de
/// chave do provider family).
typedef FiltroCompras = ({Periodo periodo, String? lojaId});

int _int(Object? v) => (v as num).toInt();

class TotalMes {
  const TotalMes(this.mes, this.totalCent, this.nCompras);

  /// Dia 1 do mês.
  final DateTime mes;
  final int totalCent;
  final int nCompras;
}

class TotalLoja {
  const TotalLoja(this.lojaId, this.totalCent, this.nCompras);
  final String lojaId;
  final int totalCent;
  final int nCompras;
}

class TotalCategoria {
  const TotalCategoria(this.categoriaId, this.totalCent);

  /// null = sem categoria.
  final String? categoriaId;
  final int totalCent;
}

class TotalArtigo {
  const TotalArtigo(this.artigoId, this.totalCent, this.nLinhas);
  final String artigoId;
  final int totalCent;
  final int nLinhas;
}

/// Resultado da RPC `painel`.
class DadosPainel {
  const DadosPainel({
    required this.totalCent,
    required this.nCompras,
    required this.poupancaCent,
    required this.porMes,
    required this.porLoja,
    required this.porCategoria,
    required this.artigos,
  });

  final int totalCent;
  final int nCompras;
  final int poupancaCent;
  final List<TotalMes> porMes;
  final List<TotalLoja> porLoja;
  final List<TotalCategoria> porCategoria;
  final List<TotalArtigo> artigos;

  /// Média por compra em cêntimos, arredondada; 0 se não há compras.
  int get mediaCent => nCompras == 0 ? 0 : (totalCent / nCompras).round();

  /// Lê o JSON da RPC (os números podem chegar como `int` ou `num`).
  factory DadosPainel.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> lista(String chave) =>
        (j[chave] as List).cast<Map<String, dynamic>>();
    return DadosPainel(
      totalCent: _int(j['total_cent']),
      nCompras: _int(j['n_compras']),
      poupancaCent: _int(j['poupanca_cent']),
      porMes: [
        for (final m in lista('por_mes'))
          TotalMes(
            _mesDeTexto(m['mes'] as String),
            _int(m['total_cent']),
            _int(m['n_compras']),
          ),
      ],
      porLoja: [
        for (final m in lista('por_loja'))
          TotalLoja(
            m['loja_id'] as String,
            _int(m['total_cent']),
            _int(m['n_compras']),
          ),
      ],
      porCategoria: [
        for (final m in lista('por_categoria'))
          TotalCategoria(m['categoria_id'] as String?, _int(m['total_cent'])),
      ],
      artigos: [
        for (final m in lista('artigos'))
          TotalArtigo(
            m['artigo_id'] as String,
            _int(m['total_cent']),
            _int(m['n_linhas']),
          ),
      ],
    );
  }

  /// Mesmo formato que a RPC devolve (para a cache).
  Map<String, dynamic> toJson() => {
    'total_cent': totalCent,
    'n_compras': nCompras,
    'poupanca_cent': poupancaCent,
    'por_mes': [
      for (final m in porMes)
        {
          'mes': _mesParaTexto(m.mes),
          'total_cent': m.totalCent,
          'n_compras': m.nCompras,
        },
    ],
    'por_loja': [
      for (final l in porLoja)
        {
          'loja_id': l.lojaId,
          'total_cent': l.totalCent,
          'n_compras': l.nCompras,
        },
    ],
    'por_categoria': [
      for (final c in porCategoria)
        {'categoria_id': c.categoriaId, 'total_cent': c.totalCent},
    ],
    'artigos': [
      for (final a in artigos)
        {
          'artigo_id': a.artigoId,
          'total_cent': a.totalCent,
          'n_linhas': a.nLinhas,
        },
    ],
  };
}

/// `YYYY-MM` → dia 1 desse mês.
DateTime _mesDeTexto(String s) {
  final partes = s.split('-');
  return DateTime(int.parse(partes[0]), int.parse(partes[1]), 1);
}

String _mesParaTexto(DateTime m) =>
    '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

/// Um [TotalMes] por cada mês de [de] a [ate], com zeros nos meses sem compras.
List<TotalMes> mesesCompletos(
  List<TotalMes> porMes,
  DateTime de,
  DateTime ate,
) {
  final existentes = {for (final m in porMes) m.mes: m};
  final fim = DateTime(ate.year, ate.month, 1);
  final r = <TotalMes>[];
  for (var m = DateTime(de.year, de.month, 1); !m.isAfter(fim);) {
    r.add(existentes[m] ?? TotalMes(m, 0, 0));
    m = DateTime(m.year, m.month + 1, 1);
  }
  return r;
}

/// As [n] primeiras categorias e o resto somado em `outrasCent` (0 se não
/// houver resto). A lista já vem ordenada.
({List<TotalCategoria> topo, int outrasCent}) categoriasTopo(
  List<TotalCategoria> todas, {
  int n = 8,
}) {
  final topo = todas.take(n).toList();
  final outras = todas.skip(n).fold<int>(0, (s, c) => s + c.totalCent);
  return (topo: topo, outrasCent: outras);
}

/// Resultado do painel com a origem: do servidor ou da cache.
class ResultadoPainel {
  const ResultadoPainel(this.dados, {this.guardadoEm});
  final DadosPainel dados;

  /// Preenchido quando os dados vêm da cache (sem rede).
  final DateTime? guardadoEm;
}

/// Uma compra no histórico (linha da RPC `historico_compras`).
class CompraResumo {
  const CompraResumo({
    required this.id,
    required this.lojaId,
    required this.data,
    this.local,
    required this.totalCent,
    required this.poupancaCent,
    required this.origem,
    required this.rever,
    required this.nLinhas,
  });

  final String id;
  final String lojaId;
  final DateTime data;
  final String? local;
  final int totalCent;
  final int poupancaCent;
  final String origem;
  final bool rever;
  final int nLinhas;

  factory CompraResumo.fromMap(Map<String, dynamic> m) => CompraResumo(
    id: m['id'] as String,
    lojaId: m['loja_id'] as String,
    data: DateTime.parse(m['data'] as String),
    local: m['local'] as String?,
    totalCent: _int(m['total_cent']),
    poupancaCent: _int(m['poupanca_cent']),
    origem: m['origem'] as String,
    rever: m['rever'] as bool,
    nLinhas: _int(m['n_linhas']),
  );
}

/// Agrupa as compras (já ordenadas por data desc) por mês, mantendo a ordem.
List<({DateTime mes, List<CompraResumo> compras, int totalCent})> porMes(
  List<CompraResumo> compras,
) {
  final grupos = <DateTime, List<CompraResumo>>{};
  for (final c in compras) {
    (grupos[DateTime(c.data.year, c.data.month, 1)] ??= []).add(c);
  }
  return [
    for (final e in grupos.entries)
      (
        mes: e.key,
        compras: e.value,
        totalCent: e.value.fold<int>(0, (s, c) => s + c.totalCent),
      ),
  ];
}
