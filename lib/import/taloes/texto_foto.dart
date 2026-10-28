/// OCR de fotografias de talões no aparelho, com o ML Kit (modelo latino
/// embutido, sem rede; só Android). A fotografia não sai do telemóvel.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ler_fotos.dart';
import 'linhas_ocr.dart';

Future<List<CaixaOcr>> _ler(TextRecognizer ocr, InputImage imagem) async {
  final r = await ocr.processImage(imagem);
  return [
    for (final b in r.blocks)
      for (final l in b.lines)
        CaixaOcr(
          texto: l.text,
          esquerda: l.boundingBox.left,
          cima: l.boundingBox.top,
          direita: l.boundingBox.right,
          baixo: l.boundingBox.bottom,
          angulo: l.angle ?? 0,
        ),
  ];
}

/// A fotografia inteira.
Future<List<CaixaOcr>> caixasDaFoto(String caminho) async {
  final ocr = TextRecognizer();
  try {
    return await _ler(ocr, InputImage.fromFilePath(caminho));
  } finally {
    await ocr.close();
  }
}

/// A fotografia em faixas ampliadas ([faixasDa]), passadas ao ML Kit em
/// memória.
Future<List<CaixaOcr>> caixasEmFaixas(String caminho) async {
  final codec = await ui.instantiateImageCodec(
    await File(caminho).readAsBytes(),
  );
  final imagem = (await codec.getNextFrame()).image;
  final ocr = TextRecognizer();
  try {
    final caixas = <CaixaOcr>[];
    for (final f in faixasDa(imagem.width, imagem.height)) {
      final w = (imagem.width * f.escala).round();
      final h = (f.altura * f.escala).round();
      final gravador = ui.PictureRecorder();
      ui.Canvas(gravador).drawImageRect(
        imagem,
        ui.Rect.fromLTWH(0, f.y, imagem.width.toDouble(), f.altura),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final faixa = await gravador.endRecording().toImage(w, h);
      try {
        final rgba = await faixa.toByteData(format: ui.ImageByteFormat.rawRgba);
        final lidas = await _ler(
          ocr,
          InputImage.fromBitmap(
            bitmap: rgba!.buffer.asUint8List(),
            width: w,
            height: h,
          ),
        );
        caixas.addAll(caixasDaFaixa(lidas, f));
      } finally {
        faixa.dispose();
      }
    }
    return caixas;
  } finally {
    await ocr.close();
    imagem.dispose();
    codec.dispose();
  }
}

/// O OCR do aparelho, para [lerFotos].
const LeitorOcr ocrDoAparelho = (
  inteira: caixasDaFoto,
  emFaixas: caixasEmFaixas,
);
