/// Leitor dos talões do E.Leclerc: texto do pdfrx (PDF) e do OCR (papel). Só
/// há um exemplo real de cada: variantes desconhecidas (ex.: descontos) ficam
/// em naoReconhecidas.
library;

import 'lidl.dart' show capitalizar;
import 'talao.dart';

// O IVA ("23%") vem à frente da linha; no papel, o OCR põe-no muitas vezes
// numa linha à parte ou lê o "%" como um algarismo ("238").
const _iva = r'(?:\d{1,3}[%$]? )?';
// No papel a quantidade às vezes não sai: as linhas simples são de 1.
final _simples = RegExp(
  '^$_iva'
  r'(?:\* )?(.+?) (\d+\.\d{2})(?: (\d+))?$',
);
// "2 X 5.89€ 11.78 2"; no papel o preço unitário sai ilegível ("5.8'C").
final _segunda = RegExp(
  '^$_iva'
  r'(\d+) ?X ?(\S*) (\d+\.\d{2}) (\d+)$',
);
final _unitario = RegExp(r'^(\d+\.\d{2})€$');
final _soIva = RegExp(r'^(?:\d{1,3}[%$]?|[IT][UV]A)$');
final _seccao = RegExp(r'^[>»]+ ?(.+)$');
final _separador = RegExp(r'^-+$');
final _temValor = RegExp(r'\d+\.\d{2}');
// No papel o OCR estraga às vezes a palavra ("artigns").
final _total = RegExp(r'^Total \d+ art\w+ (\d+\.\d{2})$');
// No papel o ano da linha "Caixa" sai estragado; vem da linha seguinte.
final _caixa = RegExp(r'^Caixa .* (\S+)-(\d{2})-(\d{2}) \d{2}:\d{2}$');
final _ano = RegExp(r'^\d{2}/\d{2}/(\d{2}) ');
final _cabecalho = RegExp(r'C/I[VU]A');
final _espacadas = RegExp(r'^(?:\S )+\S$');
// No papel: "E.Leclerc ()", "E.Lerlerc ()"…
final _logotipo = RegExp(r'^E\.Le\w{3,5}c\b', multiLine: true);
final _numero = RegExp(r'^\d{10,}\w*$');

/// null se o texto não é de um talão do E.Leclerc. Lança [FormatException]
/// se é, mas falta a data ou o total.
TalaoLido? lerLeclerc(String texto) {
  if (!texto.contains('E.LECLERC') &&
      !texto.contains('TRONCADIS') &&
      !_logotipo.hasMatch(texto)) {
    return null;
  }
  final ls = linhasDe(texto);
  final iCaixa = ls.indexWhere(_caixa.hasMatch);
  if (iCaixa < 0) throw const FormatException('Talão sem data');
  final caixa = _caixa.firstMatch(ls[iCaixa])!;
  final ano = RegExp(r'^\d{4}$').hasMatch(caixa[1]!)
      ? int.parse(caixa[1]!)
      : switch (ls.skip(iCaixa + 1).take(2).map(_ano.firstMatch).nonNulls) {
          final m when m.isNotEmpty => 2000 + int.parse(m.first[1]!),
          _ => throw const FormatException('Talão sem data'),
        };

  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  int? total;
  String? seccao;
  // Texto numa linha; quantidade e valores na seguinte.
  String? pendente;

  final inicio = ls.indexWhere((l) => l.contains(_cabecalho)) + 1;
  for (final l in ls.skip(inicio)) {
    if (_total.firstMatch(l) case final m?) {
      total = centTalao(m[1]!);
      break;
    }
    if (_separador.hasMatch(l) || _soIva.hasMatch(l)) continue;
    if (_segunda.firstMatch(l) case final m? when pendente != null) {
      final q = int.parse(m[1]!);
      final bruto = centTalao(m[3]!);
      final unitario = _unitario.firstMatch(m[2]!);
      linhas.add(
        LinhaTalao(
          texto: pendente,
          quantidade: q,
          precoUnitCent: unitario != null
              ? centTalao(unitario[1]!)
              : (bruto / q).round(),
          brutoCent: bruto,
          seccao: seccao,
        ),
      );
      pendente = null;
      continue;
    }
    if (pendente != null) estranhas.add(pendente);
    pendente = null;

    if (_seccao.firstMatch(l) case final m?) {
      seccao = m[1];
    } else if (_simples.firstMatch(l) case final m?) {
      final q = int.parse(m[3] ?? '1');
      final bruto = centTalao(m[2]!);
      linhas.add(
        LinhaTalao(
          texto: m[1]!,
          quantidade: q,
          precoUnitCent: q > 0 && bruto % q == 0 ? bruto ~/ q : bruto,
          brutoCent: bruto,
          seccao: seccao,
        ),
      );
    } else if (!_temValor.hasMatch(l)) {
      pendente = l;
    } else {
      estranhas.add(l);
    }
  }
  if (pendente != null) estranhas.add(pendente);
  if (total == null) throw const FormatException('Talão sem total');

  // No PDF o cabeçalho vem com as letras espaçadas ("E N T R O N C A M E N T
  // O"): perdem-se os espaços entre palavras, por isso só se lê bem uma
  // palavra. No papel a localidade sai estragada: fica sem local.
  final sitio = ls.length > 1 && _espacadas.hasMatch(ls[1])
      ? ls[1].replaceAll(' ', '')
      : '';
  return TalaoLido(
    loja: 'E.Leclerc',
    local: sitio.isEmpty ? null : 'E.Leclerc ${capitalizar(sitio)}',
    data: DateTime(ano, int.parse(caixa[2]!), int.parse(caixa[3]!)),
    numero: ls.skip(iCaixa + 1).take(3).where(_numero.hasMatch).firstOrNull,
    linhas: linhas,
    totalCent: total,
    naoReconhecidas: estranhas,
  );
}
