import 'dart:io';

import 'package:cabaz_mensal/import/taloes/ler_fotos.dart';
import 'package:cabaz_mensal/import/taloes/ler_talao.dart';
import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

/// Uma caixa por linha do texto, como se o OCR tivesse lido a linha inteira.
List<CaixaOcr> _caixas(String texto) => [
  for (final (i, l) in texto.split('\n').indexed)
    if (l.trim().isNotEmpty)
      CaixaOcr(
        texto: l.trim(),
        esquerda: 10,
        cima: i * 40.0,
        direita: 600,
        baixo: i * 40.0 + 30,
      ),
];

/// OCR falso: textos por caminho; conta as chamadas às faixas.
class _Ocr {
  _Ocr({required this.inteira, this.faixas = const {}});
  final Map<String, String> inteira;
  final Map<String, String> faixas;
  final pedidasFaixas = <String>[];

  LeitorOcr get leitor => (
    inteira: (c) async =>
        inteira[c] == null ? throw Exception('ilegível') : _caixas(inteira[c]!),
    emFaixas: (c) async {
      pedidasFaixas.add(c);
      return _caixas(faixas[c] ?? '');
    },
  );
}

void main() {
  final mercadona = _fixture('mercadona');
  final lidl = _fixture('lidl');

  test('imagem inteira que bate: não lê em faixas', () async {
    final ocr = _Ocr(inteira: {'a': mercadona});
    final r = await lerFotos([
      (nome: 'Fotografia 1', caminho: 'a'),
    ], ocr.leitor);
    expect(ocr.pedidasFaixas, isEmpty);
    expect(r.ilegiveis, isEmpty);
    expect(r.lidos.single.ficheiro, 'Fotografia 1');
    expect(lerTalao(r.lidos.single.texto)!.bate, isTrue);
  });

  test('inteira não reconhecida: usa as faixas', () async {
    final ocr = _Ocr(inteira: {'a': 'LDL Vale\nGARBAGE'}, faixas: {'a': lidl});
    final r = await lerFotos([(nome: 'F', caminho: 'a')], ocr.leitor);
    expect(ocr.pedidasFaixas, ['a']);
    expect(lerTalao(r.lidos.single.texto)!.loja, 'Lidl');
  });

  test('com linhas por reconhecer: fica a que tem menos', () async {
    final duas = mercadona.replaceFirst(
      '3 PAO DE FORMA',
      'XX ESTRANHA\nYY ESTRANHA\n3 PAO DE FORMA',
    );
    final uma = mercadona.replaceFirst(
      '3 PAO DE FORMA',
      'XX ESTRANHA\n3 PAO DE FORMA',
    );
    final ocr = _Ocr(inteira: {'a': duas}, faixas: {'a': uma});
    final r = await lerFotos([(nome: 'F', caminho: 'a')], ocr.leitor);
    expect(lerTalao(r.lidos.single.texto)!.naoReconhecidas, ['XX ESTRANHA']);

    // E ao contrário fica a inteira.
    final ocr2 = _Ocr(inteira: {'a': uma}, faixas: {'a': duas});
    final r2 = await lerFotos([(nome: 'F', caminho: 'a')], ocr2.leitor);
    expect(lerTalao(r2.lidos.single.texto)!.naoReconhecidas, ['XX ESTRANHA']);
  });

  test('a que bate ganha à que só é reconhecida', () async {
    final semBater = mercadona
        .replaceAll('TOTAL 7,9', 'TOTAL 9,99')
        .replaceAll('CARTAO BANCARIO 7,94', 'CARTAO BANCARIO 9,99')
        .replaceAll('COMPRA 7,94€', 'COMPRA 9,99€')
        .replaceAll(RegExp(r'B 6%.*\nD 23%.*\n'), '');
    final ocr = _Ocr(inteira: {'a': semBater}, faixas: {'a': mercadona});
    final r = await lerFotos([(nome: 'F', caminho: 'a')], ocr.leitor);
    expect(lerTalao(r.lidos.single.texto)!.bate, isTrue);
  });

  test('nenhuma reconhecida: segue o texto da inteira (a análise diz '
      'porquê)', () async {
    final ocr = _Ocr(inteira: {'a': 'NADA'}, faixas: {'a': 'OUTRA COISA'});
    final r = await lerFotos([(nome: 'F', caminho: 'a')], ocr.leitor);
    expect(r.lidos.single.texto, 'NADA');
  });

  test('erro do OCR: fotografia ilegível, as outras seguem', () async {
    final ocr = _Ocr(inteira: {'b': mercadona});
    final progresso = <(int, int)>[];
    final r = await lerFotos(
      [(nome: 'F1', caminho: 'a'), (nome: 'F2', caminho: 'b')],
      ocr.leitor,
      progresso: (f, t) => progresso.add((f, t)),
    );
    expect(r.ilegiveis.single.ficheiro, 'F1');
    expect(r.ilegiveis.single.motivo, 'Fotografia ilegível');
    expect(r.lidos.single.ficheiro, 'F2');
    expect(progresso, [(0, 2), (1, 2)]);
  });

  test('apagarFotosTemporarias só apaga o que está numa pasta cache', () {
    final raiz = Directory.systemTemp.createTempSync('fotos');
    addTearDown(() => raiz.deleteSync(recursive: true));
    final cache = Directory('${raiz.path}/cache/abc')
      ..createSync(recursive: true);
    final temporaria = File('${cache.path}/talao.jpg')..writeAsStringSync('x');
    final original = File('${raiz.path}/DCIM/talao.jpg')
      ..createSync(recursive: true);
    apagarFotosTemporarias([
      temporaria.path,
      original.path,
      '${cache.path}/ja-nao-existe.jpg',
    ]);
    expect(temporaria.existsSync(), isFalse);
    expect(original.existsSync(), isTrue);
  });
}
