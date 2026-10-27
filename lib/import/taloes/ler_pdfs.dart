/// Lê vários PDFs de talões; os que não abrem ficam como não reconhecidos.
library;

import 'dart:typed_data';

import 'importar_taloes.dart';
import 'texto_pdf.dart';

Future<
  ({
    List<({String ficheiro, String texto})> lidos,
    List<NaoReconhecido> ilegiveis,
  })
>
lerPdfs(
  List<({String nome, Uint8List bytes})> ficheiros,
  LerTextoPdf ler, {
  void Function(int feitos, int total)? progresso,
}) async {
  final lidos = <({String ficheiro, String texto})>[];
  final ilegiveis = <NaoReconhecido>[];
  for (final (i, f) in ficheiros.indexed) {
    progresso?.call(i, ficheiros.length);
    try {
      lidos.add((ficheiro: f.nome, texto: await ler(f.bytes)));
    } on FormatException {
      ilegiveis.add(NaoReconhecido(f.nome, 'PDF ilegível'));
    }
  }
  return (lidos: lidos, ilegiveis: ilegiveis);
}
