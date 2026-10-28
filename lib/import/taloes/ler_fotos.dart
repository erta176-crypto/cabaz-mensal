/// Lê fotografias de talões: imagem inteira primeiro e, se não chegar, em
/// faixas (decisão D3 da Fase 7). Devolve o texto de cada uma para a mesma
/// análise dos PDFs.
library;

import 'dart:io';

import 'importar_taloes.dart';
import 'ler_talao.dart';
import 'linhas_ocr.dart';
import 'talao.dart';

/// Caixas de texto de uma fotografia. Injetável nos testes.
typedef LerCaixas = Future<List<CaixaOcr>> Function(String caminho);
typedef LeitorOcr = ({LerCaixas inteira, LerCaixas emFaixas});

String _texto(List<CaixaOcr> caixas) => normalizarOcr(linhasDasCaixas(caixas));

TalaoLido? _tentar(String texto) {
  try {
    return lerTalao(texto);
  } on FormatException {
    return null;
  }
}

/// Melhor primeiro: bate; depois reconhecido; depois menos linhas por
/// reconhecer.
int _nota(TalaoLido? t) =>
    t == null ? -1000000 : (t.bate ? 100000 : 0) - t.naoReconhecidas.length;

Future<
  ({
    List<({String ficheiro, String texto})> lidos,
    List<NaoReconhecido> ilegiveis,
  })
>
lerFotos(
  List<({String nome, String caminho})> fotos,
  LeitorOcr ocr, {
  void Function(int feitos, int total)? progresso,
}) async {
  final lidos = <({String ficheiro, String texto})>[];
  final ilegiveis = <NaoReconhecido>[];
  for (final (i, f) in fotos.indexed) {
    progresso?.call(i, fotos.length);
    try {
      var texto = _texto(await ocr.inteira(f.caminho));
      final t = _tentar(texto);
      if (t == null || !t.bate || t.naoReconhecidas.isNotEmpty) {
        final emFaixas = _texto(await ocr.emFaixas(f.caminho));
        if (_nota(_tentar(emFaixas)) > _nota(t)) texto = emFaixas;
      }
      lidos.add((ficheiro: f.nome, texto: texto));
    } on Exception {
      ilegiveis.add(NaoReconhecido(f.nome, 'Fotografia ilegível'));
    }
  }
  return (lidos: lidos, ilegiveis: ilegiveis);
}

/// Apaga as cópias temporárias das fotografias (D1). Só apaga ficheiros
/// dentro de uma pasta "cache" (onde o image_picker as copia): nunca a
/// fotografia original da galeria.
void apagarFotosTemporarias(Iterable<String> caminhos) {
  for (final c in caminhos) {
    final partes = File(c).absolute.uri.pathSegments;
    if (!partes.contains('cache')) continue;
    try {
      File(c).deleteSync();
    } on FileSystemException {
      // Já não existe: nada a apagar.
    }
  }
}
