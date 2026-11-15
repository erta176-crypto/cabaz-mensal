import 'dart:convert';
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
    // No Linux (CI), o pdfium_dart procura o PDFium junto do flutter_tester
    // ou em .dart_tool/native_assets.yaml; o flutter test põe-no em
    // build/native_assets/<sistema>/ e escreve o caminho neste ficheiro.
    final assets = File(
      'build/native_assets/${Platform.operatingSystem}/native_assets.json',
    );
    if (assets.existsSync()) {
      final porAlvo =
          (jsonDecode(assets.readAsStringSync())
                  as Map<String, dynamic>)['native-assets']
              as Map<String, dynamic>;
      for (final alvo in porAlvo.values.cast<Map<String, dynamic>>()) {
        final pdfium = alvo['package:pdfium_dart/libpdfium'] as List?;
        if (pdfium != null) Pdfrx.pdfiumModulePath = pdfium[1] as String;
      }
    }
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
