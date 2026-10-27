import 'dart:io';

import 'package:cabaz_mensal/import/taloes/pingo_doce.dart';
import 'package:cabaz_mensal/import/taloes/talao.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture() =>
    File('test/fixtures/taloes/pingo_doce.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

void main() {
  late TalaoLido t;
  setUp(() => t = lerPingoDoce(_fixture())!);

  test('cabeçalho: loja, local, data e número', () {
    expect(t.loja, 'Pingo Doce');
    expect(t.local, 'Pingo Doce Vila Ficticia Centro');
    expect(t.data, DateTime(2026, 10, 5));
    expect(t.numero, 'FS 0000000000000/000001');
  });

  test('peso com 3 casas e "KG" no texto', () {
    final l = t.linhas[0];
    expect(l.texto, 'PESCADA POSTA KG');
    expect(l.pesoG, 332);
    expect(l.quantidade, isNull);
    expect(l.precoUnitCent, 1000);
    expect(l.brutoCent, 332);
    expect(l.descontoCent, 32); // Poupança Imediata
    expect(l.seccao, 'PEIXARIA');
  });

  test('quantidade inteira (2,000 X …) e peso sem "KG" (1,250 X …)', () {
    expect(t.linhas[1].texto, 'SALADA MISTA');
    expect(t.linhas[1].quantidade, 2);
    expect(t.linhas[1].pesoG, isNull);
    expect(t.linhas[1].precoUnitCent, 90);
    expect(t.linhas[2].texto, 'MAÇÃ GALA');
    expect(t.linhas[2].pesoG, 1250);
    expect(t.linhas[2].seccao, 'FRUTAS E VEGETAIS');
  });

  test('linha sem X: quantidade 1; secção com "+"', () {
    final l = t.linhas[3];
    expect(l.texto, 'BOLACHA MARIA');
    expect(l.quantidade, 1);
    expect(l.precoUnitCent, 120);
    expect(l.descontoCent, 20);
    expect(l.seccao, 'MERCEARIA + PET FOOD');
    expect(t.linhas[4].quantidade, 3);
    // Outras promoções do artigo: "Exclusivo APP/Poupa Mais (0,05)".
    expect(t.linhas[4].descontoCent, 5);
  });

  test('desconto da compra, total a pagar e soma que bate', () {
    expect(t.linhas, hasLength(5));
    expect(t.descontoCompraCent, 200);
    expect(t.totalCent, 955); // TOTAL A PAGAR, não TOTAL
    expect(t.naoReconhecidas, isEmpty);
    expect(t.bate, isTrue);
  });

  test('linha estranha fica de fora e a soma deixa de bater', () {
    final r = lerPingoDoce(
      _fixture().replaceFirst(
        ' E BOLACHA MARIA 1,20',
        ' E BOLACHA MARIA 1,20\n ??? LINHA ESTRANHA',
      ),
    )!;
    expect(r.naoReconhecidas, ['??? LINHA ESTRANHA']);
    expect(r.bate, isTrue);

    final m = lerPingoDoce(
      _fixture().replaceFirst('9,55\nPagamentos', '9,70\nPagamentos'),
    )!;
    expect(m.bate, isFalse);
  });

  test('texto de outra loja → null', () {
    expect(lerPingoDoce('LIDL & Cia - SITIO\nEUR\nTotal 1,00'), isNull);
  });

  test('Pingo Doce sem data → FormatException', () {
    expect(
      () => lerPingoDoce(
        _fixture().replaceFirst('Data de emissão:05/10/2026', ''),
      ),
      throwsFormatException,
    );
  });
}
