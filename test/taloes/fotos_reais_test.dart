// Verificação com o OCR real de dados-privados/ocr-prova/ (fora do git; tirado
// no telemóvel na prova da Fase 7). Sem essa pasta o teste é saltado. Só
// mostra contagens: nenhum texto de talão real sai daqui.
import 'dart:convert';
import 'dart:io';

import 'package:cabaz_mensal/import/taloes/ler_fotos.dart';
import 'package:cabaz_mensal/import/taloes/ler_talao.dart';
import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

final _pasta = Directory('dados-privados/ocr-prova');

List<CaixaOcr> _caixas(String ficheiro) {
  final d = jsonDecode(File('${_pasta.path}/$ficheiro').readAsStringSync());
  return [
    for (final l in d['linhas'] as List)
      CaixaOcr(
        texto: l['t'] as String,
        esquerda: (l['r'][0] as num).toDouble(),
        cima: (l['r'][1] as num).toDouble(),
        direita: (l['r'][2] as num).toDouble(),
        baixo: (l['r'][3] as num).toDouble(),
        angulo: (l['a'] as num?)?.toDouble() ?? 0,
      ),
  ];
}

void main() {
  final saltar = !_pasta.existsSync() ? 'sem dados-privados/ocr-prova' : false;

  test('as fotografias de exemplo são lidas e batem', () async {
    final faixasPedidas = <String>[];
    final LeitorOcr ocr = (
      inteira: (c) async => _caixas('$c.json'),
      emFaixas: (c) async {
        faixasPedidas.add(c);
        return _caixas('faixas-$c.json');
      },
    );
    final fotos = ['mercadona.jpg', 'lidl1.png', 'lidl2.png'];
    final r = await lerFotos([
      for (final f in fotos) (nome: f, caminho: f),
    ], ocr);
    expect(r.ilegiveis, isEmpty);
    for (final l in r.lidos) {
      final t = lerTalao(l.texto)!;
      // ignore: avoid_print
      print(
        '${l.ficheiro}: ${t.loja}, ${t.linhas.length} linhas, '
        '${t.naoReconhecidas.length} por reconhecer, bate=${t.bate}',
      );
      expect(t.bate, isTrue, reason: l.ficheiro);
      expect(t.naoReconhecidas, isEmpty, reason: l.ficheiro);
    }
    // O Mercadona lê-se inteiro; as capturas do Lidl só em faixas.
    expect(faixasPedidas, ['lidl1.png', 'lidl2.png']);
  }, skip: saltar);
}
