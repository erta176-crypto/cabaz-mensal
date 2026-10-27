import 'dart:io';
import 'dart:typed_data';

import 'package:cabaz_mensal/import/taloes/texto_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

Future<Uint8List> _pdfFicticio() async {
  final doc = pw.Document()
    ..addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: [
            pw.Text('LIDL TESTE - SITIO'),
            pw.Text('MISTURA DE LEGUMES 3,98 B'),
            pw.Text('Total 3,98'),
          ],
        ),
      ),
    );
  return doc.save();
}

void main() {
  setUpAll(() {
    // No flutter test não há path_provider: a cache vai para uma pasta temporária.
    Pdfrx.cacheDirectoryPath = Directory.systemTemp
        .createTempSync('pdfrx')
        .path;
  });

  test('lê o texto de um PDF, linha a linha', () async {
    final texto = await textoDoPdf(await _pdfFicticio());
    final linhas = [
      for (final l in texto.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    expect(linhas, [
      'LIDL TESTE - SITIO',
      'MISTURA DE LEGUMES 3,98 B',
      'Total 3,98',
    ]);
  });

  test('bytes que não são PDF → FormatException', () async {
    expect(
      textoDoPdf(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
  });
}
