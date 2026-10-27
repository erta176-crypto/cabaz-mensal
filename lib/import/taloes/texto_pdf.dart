/// Texto de um PDF (talões), com o pdfrx (PDFium; na web por WASM).
library;

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Lê o texto de um PDF. Injetável nos testes.
typedef LerTextoPdf = Future<String> Function(Uint8List bytes);

/// Texto de todas as páginas, separadas por uma linha. Um PDF que não abre
/// lança [FormatException].
Future<String> textoDoPdf(Uint8List bytes) async {
  await pdfrxFlutterInitialize();
  final PdfDocument documento;
  try {
    documento = await PdfDocument.openData(bytes);
  } catch (_) {
    throw const FormatException('PDF ilegível');
  }
  try {
    final texto = StringBuffer();
    for (final pagina in documento.pages) {
      texto.writeln((await pagina.loadText())?.fullText ?? '');
    }
    return texto.toString();
  } finally {
    await documento.dispose();
  }
}
