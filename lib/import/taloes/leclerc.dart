/// Leitor dos talões do E.Leclerc (texto do pdfrx). Só há um exemplo real:
/// variantes desconhecidas (ex.: descontos) ficam em naoReconhecidas.
library;

import 'lidl.dart' show capitalizar;
import 'talao.dart';

final _simples = RegExp(r'^\d+% (?:\* )?(.+?) (\d+\.\d{2}) (\d+)$');
final _segunda = RegExp(r'^\d+% (\d+) X (\d+\.\d{2})€ (\d+\.\d{2}) (\d+)$');
final _seccao = RegExp(r'^>> (.+)$');
final _separador = RegExp(r'^-+$');
final _temValor = RegExp(r'\d+\.\d{2}');
final _total = RegExp(r'^Total \d+ artigos (\d+\.\d{2})$');
final _caixa = RegExp(r'^Caixa .* (\d{4})-(\d{2})-(\d{2}) \d{2}:\d{2}$');
final _numero = RegExp(r'^\d{10,}\w*$');

/// null se o texto não é de um talão do E.Leclerc. Lança [FormatException]
/// se é, mas falta a data ou o total.
TalaoLido? lerLeclerc(String texto) {
  if (!texto.contains('E.LECLERC') && !texto.contains('TRONCADIS')) {
    return null;
  }
  final ls = linhasDe(texto);
  final iCaixa = ls.indexWhere(_caixa.hasMatch);
  if (iCaixa < 0) throw const FormatException('Talão sem data');
  final caixa = _caixa.firstMatch(ls[iCaixa])!;

  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  int? total;
  String? seccao;
  // Texto numa linha; quantidade e valores na seguinte.
  String? pendente;

  final inicio = ls.indexWhere((l) => l.startsWith('IVA C/IVA')) + 1;
  for (final l in ls.skip(inicio)) {
    if (_total.firstMatch(l) case final m?) {
      total = centTalao(m[1]!);
      break;
    }
    if (_separador.hasMatch(l)) continue;
    if (_segunda.firstMatch(l) case final m? when pendente != null) {
      linhas.add(
        LinhaTalao(
          texto: pendente,
          quantidade: int.parse(m[1]!),
          precoUnitCent: centTalao(m[2]!),
          brutoCent: centTalao(m[3]!),
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
      final q = int.parse(m[3]!);
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

  // O cabeçalho vem com as letras espaçadas ("E N T R O N C A M E N T O"):
  // perdem-se os espaços entre palavras, por isso só se lê bem uma palavra.
  final sitio = ls.length > 1 ? ls[1].replaceAll(' ', '') : '';
  return TalaoLido(
    loja: 'E.Leclerc',
    local: sitio.isEmpty ? null : 'E.Leclerc ${capitalizar(sitio)}',
    data: DateTime(
      int.parse(caixa[1]!),
      int.parse(caixa[2]!),
      int.parse(caixa[3]!),
    ),
    numero: ls.skip(iCaixa + 1).take(3).where(_numero.hasMatch).firstOrNull,
    linhas: linhas,
    totalCent: total,
    naoReconhecidas: estranhas,
  );
}
