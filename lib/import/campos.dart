/// Campos da app a que cada coluna do ficheiro pode ser ligada, e o palpite
/// feito pelo cabeçalho (sem acentos nem maiúsculas).
library;

import '../domain/texto.dart';

enum Campo {
  ignorar('Ignorar'),
  compra('Compra'),
  data('Data'),
  loja('Loja'),
  local('Local'),
  categoria('Categoria'),
  artigo('Artigo'),
  textoTalao('Texto do talão'),
  unidade('Unidade'),
  quantidade('Quantidade'),
  peso('Peso (kg)'),
  preco('Preço'),
  precoUnit('Preço unitário'),
  bruto('Bruto'),
  desconto('Desconto'),
  pago('Pago'),
  totalCompra('Total da compra'),
  comprado('Comprado');

  const Campo(this.rotulo);
  final String rotulo;
}

enum TipoImportacao {
  artigos('Artigos e preços', [
    Campo.artigo,
    Campo.categoria,
    Campo.unidade,
    Campo.loja,
    Campo.preco,
  ]),
  compras('Compras e linhas', [
    Campo.compra,
    Campo.data,
    Campo.loja,
    Campo.local,
    Campo.artigo,
    Campo.textoTalao,
    Campo.quantidade,
    Campo.peso,
    Campo.precoUnit,
    Campo.bruto,
    Campo.desconto,
    Campo.pago,
    Campo.totalCompra,
  ]),
  lista('Lista de compras', [
    Campo.loja,
    Campo.categoria,
    Campo.artigo,
    Campo.quantidade,
    Campo.unidade,
    Campo.comprado,
  ]);

  const TipoImportacao(this.rotulo, this.campos);
  final String rotulo;
  final List<Campo> campos;
}

/// Sinónimos por campo (já normalizados). O primeiro que coincidir ganha.
const _sinonimos = <Campo, List<String>>{
  Campo.compra: ['compra', 'n compra', 'id compra', 'talao', 'n talao'],
  Campo.data: ['data', 'dia', 'data da compra'],
  Campo.loja: ['loja', 'supermercado', 'cadeia', 'mercado'],
  Campo.local: ['local', 'morada', 'localidade'],
  Campo.categoria: ['categoria', 'seccao', 'secao', 'familia', 'corredor'],
  Campo.artigo: ['artigo', 'produto', 'nome', 'item', 'descricao'],
  Campo.textoTalao: ['texto do talao', 'texto talao', 'descricao talao'],
  Campo.unidade: ['unidade', 'un', 'medida'],
  Campo.quantidade: ['quantidade', 'qtd', 'qtde', 'quant'],
  Campo.peso: ['peso (kg)', 'peso kg', 'peso', 'kg'],
  Campo.precoUnit: [
    'preco unitario',
    'preco unit',
    'preco por unidade',
    'preco/kg',
  ],
  Campo.preco: ['preco', 'pvp', 'valor', 'preco (eur)', 'preco eur'],
  Campo.bruto: ['bruto', 'valor bruto'],
  Campo.desconto: ['desconto', 'poupanca'],
  Campo.pago: ['pago', 'valor pago', 'total linha', 'liquido'],
  Campo.totalCompra: ['total da compra', 'total compra', 'total'],
  Campo.comprado: ['comprado', 'no carrinho', 'feito'],
};

/// Palpite para um cabeçalho, entre os campos do [tipo]. Nas compras,
/// "Preço" é o preço unitário.
Campo adivinharCampo(String cabecalho, TipoImportacao tipo) {
  final h = normalizar(cabecalho).trim().replaceAll(RegExp(r'\s+'), ' ');
  if (h.isEmpty) return Campo.ignorar;
  for (final c in tipo.campos) {
    if (_sinonimos[c]?.contains(h) ?? false) return c;
  }
  if (tipo == TipoImportacao.compras && _sinonimos[Campo.preco]!.contains(h)) {
    return Campo.precoUnit;
  }
  return Campo.ignorar;
}

/// Um campo por coluna; cada campo só fica ligado à primeira coluna.
List<Campo> adivinharColunas(List<String> cabecalhos, TipoImportacao tipo) {
  final usados = <Campo>{};
  return [
    for (final h in cabecalhos)
      switch (adivinharCampo(h, tipo)) {
        Campo.ignorar => Campo.ignorar,
        final c => usados.add(c) ? c : Campo.ignorar,
      },
  ];
}

/// CSV exportado pela app antiga "Lista de Compras" (PWA).
bool eFormatoAppAntiga(List<String> cabecalhos) {
  final h = {for (final c in cabecalhos) normalizar(c).trim()};
  return h.containsAll(const [
    'categoria',
    'artigo',
    'comprado',
    'quantidade',
    'supermercado',
  ]);
}
