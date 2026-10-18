/// Leitura de ficheiros CSV e XLSX para uma tabela de texto (cabeçalhos +
/// linhas), igual para os dois formatos. Sem interface: testável.
library;

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class TabelaLida {
  const TabelaLida({
    required this.cabecalhos,
    required this.linhas,
    this.folhas = const [],
    this.folha,
  });

  final List<String> cabecalhos;

  /// Linhas de dados (sem o cabeçalho), já como texto e com o mesmo
  /// número de colunas do cabeçalho.
  final List<List<String>> linhas;

  /// Folhas do XLSX (vazio no CSV) e a que foi lida.
  final List<String> folhas;
  final String? folha;
}

class FicheiroInvalido implements Exception {
  const FicheiroInvalido(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

TabelaLida lerFicheiro(String nome, List<int> bytes, {String? folha}) {
  final n = nome.toLowerCase();
  if (n.endsWith('.xlsx')) return lerXlsx(bytes, folha: folha);
  if (n.endsWith('.csv') || n.endsWith('.txt')) return lerCsv(bytes);
  throw const FicheiroInvalido('Formato não suportado (usa .csv ou .xlsx).');
}

/// CSV com BOM ou sem ele, separador `;` ou `,` (detetado no cabeçalho).
TabelaLida lerCsv(List<int> bytes) {
  var texto = utf8.decode(bytes, allowMalformed: true);
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final primeira = texto
      .split(RegExp(r'\r?\n'))
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  if (primeira.isEmpty) throw const FicheiroInvalido('O ficheiro está vazio.');
  final separador =
      ';'.allMatches(primeira).length >= ','.allMatches(primeira).length
      ? ';'
      : ',';
  final linhas = Csv(
    fieldDelimiter: separador,
    autoDetect: false,
  ).decode(texto).map((l) => [for (final c in l) '$c'.trim()]).toList();
  return _tabela(linhas);
}

/// XLSX: lê a [folha] pedida (ou a primeira). Números e datas são
/// convertidos para texto que `valores.dart` sabe ler.
TabelaLida lerXlsx(List<int> bytes, {String? folha}) {
  final Excel livro;
  try {
    livro = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FicheiroInvalido('Não foi possível abrir o ficheiro Excel.');
  }
  final folhas = livro.tables.keys.toList();
  if (folhas.isEmpty) throw const FicheiroInvalido('O Excel não tem folhas.');
  final escolhida = folhas.contains(folha) ? folha! : folhas.first;
  final linhas = [
    for (final l in livro.tables[escolhida]!.rows)
      [for (final c in l) _celula(c?.value)],
  ];
  final t = _tabela(linhas);
  return TabelaLida(
    cabecalhos: t.cabecalhos,
    linhas: t.linhas,
    folhas: folhas,
    folha: escolhida,
  );
}

String _celula(CellValue? v) => switch (v) {
  null => '',
  TextCellValue() => v.value.text?.trim() ?? '',
  IntCellValue() => '${v.value}',
  DoubleCellValue() => '${v.value}',
  BoolCellValue() => v.value ? 'Sim' : 'Não',
  DateCellValue() => _iso(v.year, v.month, v.day),
  DateTimeCellValue() => _iso(v.year, v.month, v.day),
  _ => '$v'.trim(),
};

String _iso(int a, int m, int d) =>
    '${a.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')}';

/// Primeira linha não vazia = cabeçalho; linhas vazias são descartadas e
/// as restantes ficam com o mesmo número de colunas do cabeçalho.
TabelaLida _tabela(List<List<String>> linhas) {
  final cheias = [
    for (final l in linhas)
      if (l.any((c) => c.isNotEmpty)) l,
  ];
  if (cheias.isEmpty) throw const FicheiroInvalido('O ficheiro está vazio.');
  final cab = cheias.first;
  return TabelaLida(
    cabecalhos: cab,
    linhas: [
      for (final l in cheias.skip(1))
        [for (var i = 0; i < cab.length; i++) i < l.length ? l[i] : ''],
    ],
  );
}
