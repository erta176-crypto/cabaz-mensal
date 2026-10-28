/// Leitor dos talões do Mercadona (texto do OCR de uma fotografia). Regras em
/// docs/planning/fase-7.md (T2 e D4).
library;

import 'talao.dart';

/// Quantidade, texto, preço unitário (só com quantidade > 1), valor, IVA.
final _artigo = RegExp(r'^(\d+) ?(.+?)(?: (\d+,\d{2}))? (\d+,\d{2}) [A-Z]$');
final _valorNoFim = RegExp(r' (\d+,\d{2})€?$');
final _compra = RegExp(r'COMPRA (\d+,\d{2})');
final _iva = RegExp(r'^[A-Z] \d+% \d+,\d{2} \d+,\d{2} (\d+,\d{2})$');
final _data = RegExp(r'^(\d{2})-(\d{2})-(\d{2}) \d{2}:\d{2}');

/// null se o texto não é de um talão do Mercadona. Lança [FormatException]
/// se é, mas falta a data ou o total.
TalaoLido? lerMercadona(String texto) {
  if (!texto.contains('MERCADONA')) return null;
  final ls = linhasDe(texto);

  final dataM = ls.map(_data.firstMatch).nonNulls.firstOrNull;
  if (dataM == null) throw const FormatException('Talão sem data');
  final iTotal = ls.indexWhere((l) => l.startsWith('TOTAL'));
  if (iTotal < 0) throw const FormatException('Talão sem total');

  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  final inicio = ls.indexWhere((l) => l.startsWith('Descri')) + 1;
  for (final l in ls.sublist(inicio, iTotal)) {
    final m = _artigo.firstMatch(l);
    if (m == null) {
      estranhas.add(l);
      continue;
    }
    final quantidade = int.parse(m[1]!);
    final valor = centTalao(m[4]!);
    linhas.add(
      LinhaTalao(
        texto: m[2]!,
        quantidade: quantidade,
        precoUnitCent: m[3] == null ? valor ~/ quantidade : centTalao(m[3]!),
        brutoCent: valor,
      ),
    );
  }

  // O total está impresso em vários sítios e o OCR pode errar um deles:
  // TOTAL e pagamento, "COMPRA" do terminal, soma da coluna "Valor c/IVA".
  // Vale o que bater com a soma das linhas; se nenhum bater, o primeiro.
  final iva = [
    for (final l in ls)
      if (_iva.firstMatch(l) case final m?) centTalao(m[1]!),
  ];
  final candidatos = [
    for (final l in ls.skip(iTotal).takeWhile((l) => !l.startsWith('Taxa')))
      if (_valorNoFim.firstMatch(l) case final m?) centTalao(m[1]!),
    for (final l in ls)
      if (_compra.firstMatch(l) case final m?) centTalao(m[1]!),
    if (iva.isNotEmpty) iva.reduce((a, b) => a + b),
  ];
  if (candidatos.isEmpty) throw const FormatException('Talão sem total');
  final soma = linhas.fold(0, (s, l) => s + l.brutoCent);

  return TalaoLido(
    loja: 'Mercadona',
    data: DateTime(
      2000 + int.parse(dataM[1]!),
      int.parse(dataM[2]!),
      int.parse(dataM[3]!),
    ),
    linhas: linhas,
    totalCent: candidatos.contains(soma) ? soma : candidatos.first,
    naoReconhecidas: estranhas,
  );
}
