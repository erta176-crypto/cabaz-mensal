import 'dart:io';

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

void main() {
  final texto = _fixture('mercadona');

  test('lê artigos, quantidades, preço unitário e data', () {
    final t = lerMercadona(texto)!;
    expect(t.loja, 'Mercadona');
    expect(t.data, DateTime(2026, 10, 4));
    expect(t.numero, isNull);
    expect(
      [for (final l in t.linhas) l.texto],
      ['AGUA COM GAS', 'IOGURTE NATURAL', 'CAFE MOIDO', 'PAO DE FORMA'],
    );
    expect([for (final l in t.linhas) l.quantidade], [1, 2, 1, 3]);
    expect([for (final l in t.linhas) l.precoUnitCent], [59, 45, 315, 110]);
    expect([for (final l in t.linhas) l.brutoCent], [59, 90, 315, 330]);
    expect(t.naoReconhecidas, isEmpty);
  });

  test('TOTAL com um dígito perdido: o total vem de outra linha e bate', () {
    final t = lerMercadona(texto)!;
    expect(t.totalCent, 794);
    expect(t.bate, isTrue);
  });

  test('pagamento em dinheiro, sem COMPRA nem cartão: vale o TOTAL', () {
    final t = lerMercadona(
      texto
          .replaceAll('TOTAL 7,9\n', 'TOTAL 7,94\n')
          .replaceAll('CARTAO BANCARIO 7,94\n', 'EFETIVO 10,00\n')
          .replaceAll('COMPRA 7,94€\n', '')
          .replaceAll(RegExp(r'B 6%.*\nD 23%.*\n'), ''),
    )!;
    expect(t.totalCent, 794);
    expect(t.bate, isTrue);
  });

  test('nenhum total bate com a soma: fica o TOTAL e o talão não bate', () {
    final t = lerMercadona(
      texto
          .replaceAll('TOTAL 7,9\n', 'TOTAL 8,50\n')
          .replaceAll('CARTAO BANCARIO 7,94', 'CARTAO BANCARIO 8,50')
          .replaceAll('COMPRA 7,94€', 'COMPRA 8,50€')
          .replaceAll(RegExp(r'B 6%.*\nD 23%.*\n'), ''),
    )!;
    expect(t.totalCent, 850);
    expect(t.bate, isFalse);
  });

  test('linha na zona dos artigos que não se lê fica por reconhecer', () {
    final t = lerMercadona(
      texto.replaceAll('3 PAO DE FORMA', 'BANANA 1,234 kg\n3 PAO DE FORMA'),
    )!;
    expect(t.naoReconhecidas, ['BANANA 1,234 kg']);
    expect(t.linhas, hasLength(4));
  });

  test('sem data ou sem total lança FormatException', () {
    expect(
      () => lerMercadona(texto.replaceAll(RegExp(r'26-10-04 .*\n'), '')),
      throwsFormatException,
    );
    expect(
      () => lerMercadona(
        '${texto.substring(0, texto.indexOf('TOTAL'))}'
        '26-10-04 18:56:36 Per000\n',
      ),
      throwsFormatException,
    );
  });

  test('lerTalao reconhece o Mercadona e os outros leitores não', () {
    expect(lerTalao(texto)!.loja, 'Mercadona');
    expect(lerPingoDoce(texto), isNull);
    expect(lerLidl(texto), isNull);
    expect(lerLeclerc(texto), isNull);
    for (final outro in ['pingo_doce', 'lidl', 'leclerc']) {
      expect(lerMercadona(_fixture(outro)), isNull, reason: outro);
    }
  });
}
