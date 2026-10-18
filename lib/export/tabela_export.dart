/// Tabelas a exportar (uma por folha), com cabeçalhos em português, e os
/// escritores CSV e XLSX. Os valores mantêm o tipo: [Cent] para dinheiro,
/// num para quantidades/pesos, DateTime para datas, String para o resto.
library;

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// Dinheiro em cêntimos (CSV: "1,29"; XLSX: número 1.29).
class Cent {
  const Cent(this.valor);
  final int valor;
}

class TabelaExport {
  const TabelaExport(this.nome, this.cabecalhos, this.linhas);

  final String nome;
  final List<String> cabecalhos;
  final List<List<Object?>> linhas;
}

String _numero(num v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toString().replaceAll('.', ',');

String _texto(Object? v) => switch (v) {
  null => '',
  Cent(:final valor) =>
    '${valor < 0 ? '-' : ''}${valor.abs() ~/ 100},'
        '${(valor.abs() % 100).toString().padLeft(2, '0')}',
  DateTime d =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
        '${d.year}',
  num n => _numero(n),
  _ => '$v',
};

/// CSV com ";", vírgula decimal e BOM UTF-8 (abre direto no Excel em
/// português). Só a primeira tabela.
List<int> escreverCsv(TabelaExport t) => utf8.encode(
  Csv(fieldDelimiter: ';', addBom: true).encode([
    t.cabecalhos,
    for (final l in t.linhas) [for (final v in l) _texto(v)],
  ]),
);

/// XLSX com uma folha por tabela, números como números.
List<int> escreverXlsx(List<TabelaExport> tabelas) {
  final livro = Excel.createExcel();
  final omissao = livro.getDefaultSheet();
  for (final t in tabelas) {
    final folha = livro[t.nome];
    folha.appendRow([for (final c in t.cabecalhos) TextCellValue(c)]);
    for (final l in t.linhas) {
      folha.appendRow([
        for (final v in l)
          switch (v) {
            null => null,
            Cent(:final valor) => DoubleCellValue(valor / 100),
            int n => IntCellValue(n),
            num n => DoubleCellValue(n.toDouble()),
            DateTime d => DateCellValue(
              year: d.year,
              month: d.month,
              day: d.day,
            ),
            _ => TextCellValue('$v'),
          },
      ]);
    }
  }
  if (omissao != null && !tabelas.any((t) => t.nome == omissao)) {
    livro.delete(omissao);
  }
  livro.setDefaultSheet(tabelas.first.nome);
  return livro.encode()!;
}
