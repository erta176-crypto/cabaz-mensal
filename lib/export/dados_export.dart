/// Monta as tabelas a exportar. As colunas são as que a importação lê, para
/// a ida e volta não mudar nada.
library;

import '../domain/modelos.dart';
import 'tabela_export.dart';

enum Periodo {
  esteMes('Este mês'),
  ultimos12Meses('Últimos 12 meses'),
  tudo('Todo o histórico');

  const Periodo(this.rotulo);
  final String rotulo;

  DateTime? desde(DateTime hoje) => switch (this) {
    Periodo.esteMes => DateTime(hoje.year, hoje.month),
    Periodo.ultimos12Meses => DateTime(hoje.year - 1, hoje.month, hoje.day),
    Periodo.tudo => null,
  };
}

int _porNome<T>(T a, T b, String Function(T) nome) =>
    nome(a).toLowerCase().compareTo(nome(b).toLowerCase());

/// Artigo · Categoria · Unidade · Loja · Preço (uma linha por artigo × loja
/// com preço; um artigo sem preços fica com Loja e Preço vazios).
TabelaExport tabelaArtigos({
  required List<Artigo> artigos,
  required List<Categoria> categorias,
  required List<Loja> lojas,
  required List<PrecoAtual> precos,
  String? lojaId,
}) {
  final categoria = {for (final c in categorias) c.id: c.nome};
  final lojasUsadas = [
    for (final l in lojas)
      if (lojaId == null || l.id == lojaId) l,
  ]..sort((a, b) => _porNome(a, b, (l) => l.nome));
  final preco = {for (final p in precos) '${p.artigoId}|${p.lojaId}': p.precoCent};
  final linhas = <List<Object?>>[];
  for (final a in [...artigos]..sort((a, b) => _porNome(a, b, (x) => x.nome))) {
    final base = [a.nome, categoria[a.categoriaId] ?? '', a.unidade.codigo];
    final comPreco = [
      for (final l in lojasUsadas)
        if (preco['${a.id}|${l.id}'] != null)
          [...base, l.nome, Cent(preco['${a.id}|${l.id}']!)],
    ];
    linhas.addAll(comPreco.isEmpty ? [[...base, '', null]] : comPreco);
  }
  return TabelaExport(
    'Artigos',
    const ['Artigo', 'Categoria', 'Unidade', 'Loja', 'Preço'],
    linhas,
  );
}

/// Tabela de preços (para o PDF): Artigo + uma coluna por loja.
TabelaExport tabelaPrecos({
  required List<Artigo> artigos,
  required List<Loja> lojas,
  required List<PrecoAtual> precos,
  String? lojaId,
}) {
  final ls = [
    for (final l in lojas)
      if (!l.arquivada && (lojaId == null || l.id == lojaId)) l,
  ]..sort((a, b) => _porNome(a, b, (l) => l.nome));
  final preco = {for (final p in precos) '${p.artigoId}|${p.lojaId}': p.precoCent};
  return TabelaExport('Preços', ['Artigo', for (final l in ls) l.nome], [
    for (final a in [...artigos]..sort((a, b) => _porNome(a, b, (x) => x.nome)))
      if (ls.any((l) => preco['${a.id}|${l.id}'] != null))
        [
          '${a.nome}${a.unidade == Unidade.kg ? ' (/kg)' : ''}',
          for (final l in ls)
            preco['${a.id}|${l.id}'] == null ? '' : Cent(preco['${a.id}|${l.id}']!),
        ],
  ]);
}

/// Loja · Categoria · Artigo · Quantidade · Unidade · Comprado (os artigos
/// incluídos na lista do mês).
TabelaExport tabelaLista({
  required List<ItemLista> itens,
  required List<Artigo> artigos,
  required List<Categoria> categorias,
  required List<Loja> lojas,
  String? lojaId,
}) {
  final artigo = {for (final a in artigos) a.id: a};
  final categoria = {for (final c in categorias) c.id: c};
  final loja = {for (final l in lojas) l.id: l};
  final escolhidos = [
    for (final i in itens)
      if (i.incluido &&
          artigo.containsKey(i.artigoId) &&
          loja.containsKey(i.lojaId) &&
          (lojaId == null || i.lojaId == lojaId))
        i,
  ];
  int ordem(ItemLista i) =>
      categoria[artigo[i.artigoId]!.categoriaId]?.ordem ?? 1 << 30;
  escolhidos.sort((a, b) {
    final l = loja[a.lojaId]!.nome.compareTo(loja[b.lojaId]!.nome);
    if (l != 0) return l;
    final c = ordem(a).compareTo(ordem(b));
    return c != 0
        ? c
        : _porNome(artigo[a.artigoId]!, artigo[b.artigoId]!, (x) => x.nome);
  });
  return TabelaExport(
    'Lista',
    const ['Loja', 'Categoria', 'Artigo', 'Quantidade', 'Unidade', 'Comprado'],
    [
      for (final i in escolhidos)
        [
          loja[i.lojaId]!.nome,
          categoria[artigo[i.artigoId]!.categoriaId]?.nome ?? '',
          artigo[i.artigoId]!.nome,
          i.qtd,
          artigo[i.artigoId]!.unidade.codigo,
          i.comprado ? 'Sim' : 'Não',
        ],
    ],
  );
}

/// Compras e linhas, a partir das tabelas lidas do servidor
/// (DadosRepository.lerTudo). Folha "Linhas" (a que a importação lê) e
/// folha "Compras" com o resumo.
List<TabelaExport> tabelasCompras(
  Map<String, List<Map<String, dynamic>>> tabelas, {
  DateTime? desde,
  String? lojaId,
}) {
  List<Map<String, dynamic>> t(String n) => tabelas[n] ?? const [];
  final loja = {for (final l in t('lojas')) l['id']: l['nome'] as String};
  final artigo = {
    for (final a in t('artigos'))
      if (a['apagado_em'] == null) a['id']: a['nome'] as String,
  };
  final compras = [
    for (final c in t('compras'))
      if ((lojaId == null || c['loja_id'] == lojaId) &&
          (desde == null ||
              !DateTime.parse(c['data'] as String).isBefore(desde)))
        c,
  ]..sort((a, b) {
      final d = (a['data'] as String).compareTo(b['data'] as String);
      return d != 0 ? d : '${a['id']}'.compareTo('${b['id']}');
    });
  final numero = {for (final (i, c) in compras.indexed) c['id']: i + 1};
  final linhasPorCompra = <Object?, List<Map<String, dynamic>>>{};
  for (final l in t('linhas_compra')) {
    if (numero.containsKey(l['compra_id'])) {
      (linhasPorCompra[l['compra_id']] ??= []).add(l);
    }
  }
  Cent? cent(Object? v) => v == null ? null : Cent((v as num).toInt());

  return [
    TabelaExport(
      'Linhas',
      const [
        'Compra',
        'Data',
        'Loja',
        'Local',
        'Artigo',
        'Texto do talão',
        'Quantidade',
        'Peso (kg)',
        'Preço unitário',
        'Bruto',
        'Desconto',
        'Pago',
        'Total da compra',
      ],
      [
        for (final c in compras)
          for (final l in linhasPorCompra[c['id']] ?? const <Map<String, dynamic>>[])
            [
              numero[c['id']],
              DateTime.parse(c['data'] as String),
              loja[c['loja_id']] ?? '',
              c['local'] ?? '',
              artigo[l['artigo_id']] ?? '',
              l['texto_original'] ?? '',
              l['quantidade'],
              l['peso_g'] == null ? null : (l['peso_g'] as num) / 1000,
              cent(l['preco_unit_cent']),
              cent(l['bruto_cent']),
              cent(l['desconto_cent']),
              cent(l['pago_cent']),
              cent(c['total_cent']),
            ],
      ],
    ),
    TabelaExport(
      'Compras',
      const ['Compra', 'Data', 'Loja', 'Local', 'Total', 'Poupança', 'Rever'],
      [
        for (final c in compras)
          [
            numero[c['id']],
            DateTime.parse(c['data'] as String),
            loja[c['loja_id']] ?? '',
            c['local'] ?? '',
            cent(c['total_cent']),
            cent(c['poupanca_cent']),
            c['rever'] == true ? 'Sim' : 'Não',
          ],
      ],
    ),
  ];
}
