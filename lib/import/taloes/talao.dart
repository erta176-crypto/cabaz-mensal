/// Um talão lido de um PDF, antes de passar pela importação.
/// Dinheiro em cêntimos inteiros; pesos em gramas.
library;

import '../../domain/dinheiro.dart';

class LinhaTalao {
  const LinhaTalao({
    required this.texto,
    this.quantidade,
    this.pesoG,
    required this.precoUnitCent,
    required this.brutoCent,
    this.descontoCent = 0,
    this.seccao,
  });

  /// Texto do talão, sem a letra do IVA nem marcas de promoção.
  final String texto;

  /// null quando a linha tem peso.
  final int? quantidade;
  final int? pesoG;

  /// Por unidade ou por kg.
  final int precoUnitCent;
  final int brutoCent;

  /// Descontos do próprio artigo.
  final int descontoCent;

  /// Secção do talão (ex.: 'PEIXARIA'), quando a loja as tem.
  final String? seccao;

  LinhaTalao comDesconto(int mais) => LinhaTalao(
    texto: texto,
    quantidade: quantidade,
    pesoG: pesoG,
    precoUnitCent: precoUnitCent,
    brutoCent: brutoCent,
    descontoCent: descontoCent + mais,
    seccao: seccao,
  );
}

class TalaoLido {
  const TalaoLido({
    required this.loja,
    this.local,
    required this.data,
    this.numero,
    required this.linhas,
    required this.totalCent,
    this.descontoCompraCent = 0,
    this.naoReconhecidas = const [],
  });

  /// Nome da loja como no catálogo ('Pingo Doce', 'Lidl', 'E.Leclerc').
  final String loja;
  final String? local;
  final DateTime data;
  final String? numero;
  final List<LinhaTalao> linhas;

  /// O que se pagou.
  final int totalCent;

  /// Descontos da compra inteira (ex.: Saldo Pingo Doce).
  final int descontoCompraCent;

  /// Linhas da zona dos artigos que não se reconheceram.
  final List<String> naoReconhecidas;

  /// A soma das linhas, menos os descontos.
  int get somaCent =>
      linhas.fold(0, (s, l) => s + l.brutoCent - l.descontoCent) -
      descontoCompraCent;

  /// A soma das linhas, menos os descontos, dá o total pago.
  bool get bate => somaCent == totalCent;

  /// Para as correções da pré-visualização.
  TalaoLido copyWith({
    DateTime? data,
    List<LinhaTalao>? linhas,
    int? totalCent,
    List<String>? naoReconhecidas,
  }) => TalaoLido(
    loja: loja,
    local: local,
    data: data ?? this.data,
    numero: numero,
    linhas: linhas ?? this.linhas,
    totalCent: totalCent ?? this.totalCent,
    descontoCompraCent: descontoCompraCent,
    naoReconhecidas: naoReconhecidas ?? this.naoReconhecidas,
  );
}

final _valorNoFim = RegExp(r'^(.*?) ?(\d+[,.]\d{2})(?: ?[A-Z€])?$');

/// Uma linha por reconhecer separada em texto e valor, para preencher
/// "Acrescentar linha": "BANANA 1,234 kg 1,59 B" → ("BANANA 1,234 kg", 159).
({String texto, int? valorCent}) separarValor(String linha) {
  final m = _valorNoFim.firstMatch(linha.trim());
  return m == null
      ? (texto: linha.trim(), valorCent: null)
      : (texto: m[1]!.trim(), valorCent: centDeTexto(m[2]!));
}

/// "3,32", "1.234,56" ou "3.79" → cêntimos. Lança se não for dinheiro.
int centTalao(String texto) =>
    centDeTexto(texto.replaceAll('€', '')) ??
    (throw FormatException('Valor inválido: $texto'));

/// "0,332" (kg com 3 casas) → 332 g.
int gramasTalao(String kg) => int.parse(kg.replaceAll(RegExp(r'[,.]'), ''));

/// Linhas sem espaços nas pontas e sem as vazias.
List<String> linhasDe(String texto) => [
  for (final l in texto.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];
