/// PDF da lista (para imprimir, com caixas para riscar) e de uma tabela
/// (preços). Recebe os bytes da letra, para "€" e acentos (assets/fonts).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'tabela_export.dart';
import 'texto_lista.dart';

pw.ThemeData _tema(Uint8List letra) {
  final f = pw.Font.ttf(ByteData.sublistView(letra));
  return pw.ThemeData.withFont(base: f, bold: f, italic: f, boldItalic: f);
}

Future<Uint8List> pdfLista({
  required String titulo,
  required List<BlocoLista> blocos,
  required Uint8List letra,
}) {
  final doc = pw.Document(theme: _tema(letra));
  // Os emojis não existem na letra: tiram-se do PDF (o título do bloco fica
  // só com o nome da categoria).
  String semEmoji(String s) =>
      s.replaceAll(RegExp(r'[^\u0000-ɏ€·•—–\s]'), '').trim();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Text(semEmoji(titulo), style: const pw.TextStyle(fontSize: 18)),
        for (final b in blocos) ...[
          pw.SizedBox(height: 14),
          pw.Text(semEmoji(b.titulo), style: const pw.TextStyle(fontSize: 13)),
          pw.Divider(thickness: 0.5),
          for (final l in b.linhas)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 10,
                    height: 10,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.8),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(semEmoji(l.replaceFirst('• ', ''))),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

String _celula(Object? v) => switch (v) {
  null => '',
  Cent(:final valor) =>
    '${valor ~/ 100},${(valor % 100).toString().padLeft(2, '0')} €',
  _ => '$v',
};

Future<Uint8List> pdfTabela({
  required String titulo,
  required TabelaExport tabela,
  required Uint8List letra,
}) {
  final doc = pw.Document(theme: _tema(letra));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Text(titulo, style: const pw.TextStyle(fontSize: 16)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: tabela.cabecalhos,
          data: [
            for (final l in tabela.linhas) [for (final v in l) _celula(v)],
          ],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );
  return doc.save();
}
