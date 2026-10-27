/// Leitor dos talões do Pingo Doce (texto do pdfrx). Regras em
/// docs/planning/fase-5.md, secção 0.3.
library;

import 'talao.dart';

final _comX = RegExp(r'^[A-Z] (.+?) (\d+,\d{3}) X (\d+,\d{2}) (\d+,\d{2})$');
final _simples = RegExp(r'^[A-Z] (.+?) (\d+,\d{2})$');

/// Antes de "Descontos Extra": desconto do artigo anterior; depois: da compra.
final _desconto = RegExp(r'^(.+?) \((\d+,\d{2})\)$');
final _seccao = RegExp(r'^[A-ZÀ-Ý0-9 /.,&+-]+$');
final _data = RegExp(r'Data de emiss\S*:\s*(\d{2})/(\d{2})/(\d{4})');
final _numero = RegExp(r'Fatura Simplificada (FS \S+)');
final _total = RegExp(r'^TOTAL A PAGAR (\S+)$');

/// null se o texto não é de um talão do Pingo Doce. Lança [FormatException]
/// se é, mas falta a data ou o total.
TalaoLido? lerPingoDoce(String texto) {
  if (!texto.contains('Pingo Doce - Distribui')) return null;
  final ls = linhasDe(texto);

  final dataM = ls.map(_data.firstMatch).nonNulls.firstOrNull;
  if (dataM == null) throw const FormatException('Talão sem data');
  final totalM = ls.map(_total.firstMatch).nonNulls.firstOrNull;
  if (totalM == null) throw const FormatException('Talão sem total');

  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  var descontoCompra = 0;
  var noExtra = false;
  String? seccao;

  final inicio = ls.indexOf('Artigos') + 1;
  for (final l in ls.skip(inicio).takeWhile((l) => !l.startsWith('Resumo'))) {
    if (_comX.firstMatch(l) case final m?) {
      final q = m[2]!;
      final peso = m[1]!.toUpperCase().endsWith(' KG') || !q.endsWith(',000');
      linhas.add(
        LinhaTalao(
          texto: m[1]!,
          quantidade: peso ? null : int.parse(q.split(',').first),
          pesoG: peso ? gramasTalao(q) : null,
          precoUnitCent: centTalao(m[3]!),
          brutoCent: centTalao(m[4]!),
          seccao: seccao,
        ),
      );
    } else if (_simples.firstMatch(l) case final m?) {
      final valor = centTalao(m[2]!);
      linhas.add(
        LinhaTalao(
          texto: m[1]!,
          quantidade: 1,
          precoUnitCent: valor,
          brutoCent: valor,
          seccao: seccao,
        ),
      );
    } else if (l == 'Descontos Extra') {
      noExtra = true;
    } else if (_desconto.firstMatch(l) case final m? when noExtra) {
      descontoCompra += centTalao(m[2]!);
    } else if (_desconto.firstMatch(l) case final m? when linhas.isNotEmpty) {
      // "Poupança Imediata (x)", "Exclusivo APP/Poupa Mais (x)", …
      linhas.add(linhas.removeLast().comDesconto(centTalao(m[2]!)));
    } else if (_seccao.hasMatch(l)) {
      seccao = l;
    } else {
      estranhas.add(l);
    }
  }

  final primeira = ls.first;
  return TalaoLido(
    loja: 'Pingo Doce',
    local: primeira.startsWith('PD ')
        ? 'Pingo Doce ${primeira.substring(3)}'
        : null,
    data: DateTime(
      int.parse(dataM[3]!),
      int.parse(dataM[2]!),
      int.parse(dataM[1]!),
    ),
    numero: ls.map(_numero.firstMatch).nonNulls.firstOrNull?[1],
    linhas: linhas,
    totalCent: centTalao(totalM[1]!),
    descontoCompraCent: descontoCompra,
    naoReconhecidas: estranhas,
  );
}
