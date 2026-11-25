import 'dart:io';

import 'package:cabaz_mensal/import/taloes/intermarche.dart';
import 'package:cabaz_mensal/import/taloes/leclerc.dart';
import 'package:cabaz_mensal/import/taloes/ler_talao.dart';
import 'package:cabaz_mensal/import/taloes/lidl.dart';
import 'package:cabaz_mensal/import/taloes/mercadona.dart';
import 'package:cabaz_mensal/import/taloes/pingo_doce.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

/// Talão fictício (estrutura do OCR real; valores inventados).
final _texto = _fixture('intermarche_papel');

String _trocar(String de, String para) {
  expect(_texto, contains(de));
  return _texto.replaceFirst(de, para);
}

void main() {
  test('lê loja, data, número, local, artigos e total', () {
    final t = lerIntermarche(_texto)!;
    expect(t.loja, 'Intermarché');
    expect(t.data, DateTime(2026, 11, 20));
    expect(t.numero, 'FS 0X1A00001/00001');
    expect(t.local, 'Vila Exemplo');
    expect(
      [for (final l in t.linhas) l.texto],
      [
        'ARROZ AGULHA 1KG',
        'LEITE MEIO GORDO',
        'DETERGENTE LOUCA',
        'BOLACHAS MARIA',
      ],
    );
    // As duas linhas iguais seguidas juntam-se ("x" no lugar do "*").
    expect([for (final l in t.linhas) l.quantidade], [1, 2, 1, 1]);
    expect([for (final l in t.linhas) l.precoUnitCent], [110, 80, 250, 120]);
    expect([for (final l in t.linhas) l.brutoCent], [110, 160, 250, 120]);
    expect(t.naoReconhecidas, isEmpty, reason: 'ART# não é artigo');
    expect(t.totalCent, 640);
    expect(t.bate, isTrue);
  });

  test('"COM TOTAL DE" estragado pelo OCR: vale outro total que bate', () {
    final t = lerIntermarche(
      _trocar('5 Art., COM TOTAL DE Eur6,40', '5 Art., 0OM TOTAL DE Eur6,49'),
    )!;
    expect(t.totalCent, 640);
    expect(t.bate, isTrue);
  });

  test('nenhum total bate: fica o "COM TOTAL DE" e o talão não bate', () {
    final texto = _texto
        .replaceFirst('COM TOTAL DE Eur6,40', 'COM TOTAL DE Eur6,90')
        .replaceFirst('MULTIBANCO Eur6,40', 'MULTIBANCO Eur6,91')
        .replaceFirst('TOTAL 5,71 0,69 6,40', 'TOTAL 5,71 0,69 6,92')
        .replaceFirst('COMPRA 6,40Eur', 'COMPRA 6,93Eur');
    final t = lerIntermarche(texto)!;
    expect(t.totalCent, 690);
    expect(t.bate, isFalse);
  });

  test('sem o bloco do terminal (pago em numerário): lê na mesma', () {
    final i = _texto.indexOf('INTERMARCHE V EXEMPLO');
    final t = lerIntermarche(_texto.substring(0, i))!;
    expect(t.data, DateTime(2026, 11, 20));
    expect(t.local, 'Vila Exemplo');
    expect(t.bate, isTrue);
  });

  test('sem a data da linha da hora: usa a do terminal (AA-MM-DD)', () {
    final t = lerIntermarche(_trocar('9:05:10 2026-11-20', '9:05:10'))!;
    expect(t.data, DateTime(2026, 11, 20));
  });

  test('linha que não se lê na zona dos artigos fica por reconhecer', () {
    final t = lerIntermarche(
      _trocar('*BOLACHAS MARIA Eur1,20 A', '*BOLACHAS MARIA Eurl,2O A'),
    )!;
    expect(t.naoReconhecidas, ['*BOLACHAS MARIA Eurl,2O A']);
    expect(t.bate, isFalse);
  });

  test('sem data ou sem total lança FormatException', () {
    final semData = _texto
        .replaceFirst('9:05:10 2026-11-20', '9:05:10')
        .replaceFirst('26-11-20 09:04:58', '09:04:58');
    expect(
      () => lerIntermarche(semData),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'm', 'Talão sem data'),
      ),
    );
    final semTotal = _texto
        .replaceFirst('5 Art., COM TOTAL DE Eur6,40\n', '')
        .replaceFirst('MULTIBANCO Eur6,40\n', '')
        .replaceFirst('TOTAL 5,71 0,69 6,40\n', '')
        .replaceFirst('COMPRA 6,40Eur', '');
    expect(
      () => lerIntermarche(semTotal),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'm', 'Talão sem total'),
      ),
    );
  });

  test('reconhece sem o nome da loja (pela estrutura do talão)', () {
    final texto = _texto
        .replaceFirst('IntermaRche\n', '')
        .replaceFirst('INTERMARCHE V EXEMPLO\n', '');
    expect(lerIntermarche(texto)?.loja, 'Intermarché');
  });

  test('lerTalao reconhece o Intermarché e os outros leitores não', () {
    expect(lerTalao(_texto)!.loja, 'Intermarché');
    expect(lerPingoDoce(_texto), isNull);
    expect(lerLidl(_texto), isNull);
    expect(lerLeclerc(_texto), isNull);
    expect(lerMercadona(_texto), isNull);
    for (final outro in [
      'pingo_doce',
      'pingo_doce_papel',
      'lidl',
      'leclerc',
      'leclerc_papel',
      'mercadona',
      'mercadona_pdf',
    ]) {
      expect(lerIntermarche(_fixture(outro)), isNull, reason: outro);
    }
  });
}
