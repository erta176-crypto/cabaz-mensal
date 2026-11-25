/// Leitor dos talões em papel do Intermarché (texto do OCR de uma
/// fotografia). Regras em docs/planning/fase-16.md (D2 a D5).
library;

import 'talao.dart';

/// "*DESCRIÇÃO EurN,NN A". O OCR às vezes lê o "*" como "x".
final _artigo = RegExp(r'^[*x]?\s*(.+?)\s+Eur\s?(\d+,\d{2})\s+[A-Z]$');
final _codigo = RegExp(r'^ART#');

/// "N Art., COM TOTAL DE EurNN,NN" (o "COM" pode sair estragado).
final _totalPrincipal = RegExp(r'TOTAL DE\s+Eur\s?(\d+,\d{2})');
final _pagamento = RegExp(r'^[A-Z ]+\s+Eur\s?(\d+,\d{2})$');
final _totalIva = RegExp(r'^TOTAL\s+[\d.,]+\s+[\d.,]+\s+(\d+[.,]\d{2})$');
final _compra = RegExp(r'COMPRA\s+(\d+,\d{2})');

final _data = RegExp(r'\d{1,2}:\d{2}:\d{2}\s+(\d{4})-(\d{2})-(\d{2})');
final _dataTerminal = RegExp(r'^(\d{2})-(\d{2})-(\d{2})\s+\d{2}:\d{2}');
final _numero = RegExp(r'^DOCUMENTO N\S*\s*:\s*(.+)$');
final _codigoPostal = RegExp(r'\d{4}-\d{3}\s+(.+)$');

bool _eIntermarche(String texto) {
  final t = texto.toLowerCase();
  return t.contains('intermarch') ||
      (t.contains('com total de') && t.contains('artigo'));
}

/// "VILA EXEMPLO" → "Vila Exemplo".
String _maiusculaInicial(String s) => s
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
    .join(' ');

/// null se o texto não é de um talão do Intermarché. Lança
/// [FormatException] se é, mas falta a data ou o total.
TalaoLido? lerIntermarche(String texto) {
  if (!_eIntermarche(texto)) return null;
  final ls = linhasDe(texto);

  final DateTime data;
  if (ls.map(_data.firstMatch).nonNulls.firstOrNull case final m?) {
    data = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  } else if (ls.map(_dataTerminal.firstMatch).nonNulls.firstOrNull
      case final m?) {
    data = DateTime(
      2000 + int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
    );
  } else {
    throw const FormatException('Talão sem data');
  }

  // Artigos: do cabeçalho "ARTIGO(S)" até à linha do total.
  final inicio = ls.indexWhere((l) => l.toUpperCase().startsWith('ARTIGO'));
  final iTotal = ls.indexWhere(
    (l) => _totalPrincipal.hasMatch(l) || l.contains('Art.,'),
  );
  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  final fim = iTotal < 0 ? ls.length : iTotal;
  for (final l in ls.sublist(inicio < 0 ? 0 : inicio + 1, fim)) {
    if (_codigo.hasMatch(l)) continue;
    final m = _artigo.firstMatch(l);
    if (m == null) {
      estranhas.add(l);
      continue;
    }
    final textoArtigo = m[1]!.trim();
    final valor = centTalao(m[2]!);
    // O talão imprime uma linha por unidade: as iguais seguidas juntam-se.
    final anterior = linhas.lastOrNull;
    if (anterior != null &&
        anterior.texto == textoArtigo &&
        anterior.precoUnitCent == valor) {
      final n = anterior.quantidade! + 1;
      linhas.last = LinhaTalao(
        texto: textoArtigo,
        quantidade: n,
        precoUnitCent: valor,
        brutoCent: valor * n,
      );
    } else {
      linhas.add(
        LinhaTalao(
          texto: textoArtigo,
          quantidade: 1,
          precoUnitCent: valor,
          brutoCent: valor,
        ),
      );
    }
  }

  // O total está impresso em vários sítios e o OCR pode errar um deles;
  // vale o que bater com a soma das linhas, senão o "COM TOTAL DE".
  final principal = iTotal < 0
      ? null
      : _totalPrincipal.firstMatch(ls[iTotal])?.group(1);
  final candidatos = [
    if (principal != null) centTalao(principal),
    if (iTotal >= 0)
      for (final l
          in ls.skip(iTotal + 1).takeWhile((l) => !l.startsWith('TROCO')))
        if (_pagamento.firstMatch(l) case final m?) centTalao(m[1]!),
    for (final l in ls)
      if (_totalIva.firstMatch(l) case final m?)
        centTalao(m[1]!.replaceAll('.', ',')),
    for (final l in ls)
      if (_compra.firstMatch(l) case final m?) centTalao(m[1]!),
  ];
  if (candidatos.isEmpty) throw const FormatException('Talão sem total');
  final soma = linhas.fold(0, (s, l) => s + l.brutoCent);

  return TalaoLido(
    loja: 'Intermarché',
    local: ls
        .map(_codigoPostal.firstMatch)
        .nonNulls
        .map((m) => _maiusculaInicial(m[1]!.trim()))
        .firstOrNull,
    data: data,
    numero: ls.map(_numero.firstMatch).nonNulls.firstOrNull?.group(1)?.trim(),
    linhas: linhas,
    totalCent: candidatos.contains(soma) ? soma : candidatos.first,
    naoReconhecidas: estranhas,
  );
}
