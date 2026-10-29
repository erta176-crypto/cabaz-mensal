import 'dart:io';

import 'package:cabaz_mensal/import/taloes/leclerc.dart';
import 'package:cabaz_mensal/import/taloes/ler_talao.dart';
import 'package:cabaz_mensal/import/taloes/lidl.dart';
import 'package:flutter_test/flutter_test.dart';

String _f(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

void main() {
  group('Lidl', () {
    final t = lerLidl(_f('lidl'))!;

    test('cabeçalho', () {
      expect(t.loja, 'Lidl');
      expect(t.local, 'Lidl Vila Ficticia');
      expect(t.data, DateTime(2026, 10, 4));
      expect(t.numero, 'FS 000000000/000001');
    });

    test(
      'forma em 3 linhas (texto, "3 x 1,29", "3,87 B") e o seu desconto',
      () {
        final l = t.linhas[0];
        expect(l.texto, 'SALADA COM COENTROS');
        expect(l.quantidade, 3);
        expect(l.precoUnitCent, 129);
        expect(l.brutoCent, 387);
        expect(l.descontoCent, 78);
      },
    );

    test('peso na linha seguinte (o separador a meio não termina)', () {
      final l = t.linhas[1];
      expect(l.texto, 'BIFE DE FRANGO');
      expect(l.pesoG, 519);
      expect(l.quantidade, isNull);
      expect(l.precoUnitCent, 699);
      expect(l.brutoCent, 363);
    });

    test('quantidade na mesma linha e na linha seguinte', () {
      expect(t.linhas[2].texto, 'PAO FORMA 14 CEREAIS');
      expect(t.linhas[2].quantidade, 2);
      expect(t.linhas[2].precoUnitCent, 129);
      expect(t.linhas[2].brutoCent, 258);
      expect(t.linhas[4].texto, 'MARINADAS PARA FRANGO');
      expect(t.linhas[4].quantidade, 2);
      expect(t.linhas[4].precoUnitCent, 85);
    });

    test('as três formas de desconto e a soma que bate', () {
      expect(t.linhas[3].descontoCent, 1); // Promoção
      expect(t.linhas[5].descontoCent, 50); // Promoção Lidl Plus
      expect(t.linhas, hasLength(6));
      expect(t.totalCent, 1477);
      expect(t.naoReconhecidas, isEmpty);
      expect(t.bate, isTrue);
    });

    test('outro texto → null', () => expect(lerLidl('Pingo Doce'), isNull));
  });

  group('E.Leclerc', () {
    final t = lerLeclerc(_f('leclerc'))!;

    test('cabeçalho com letras espaçadas, data e número', () {
      expect(t.loja, 'E.Leclerc');
      expect(t.local, 'E.Leclerc Ficticia'); // letras espaçadas: só uma palavra
      expect(t.data, DateTime(2026, 10, 24));
      expect(t.numero, '00000000000000001MP01V00');
    });

    test('linhas: simples, em duas partes, com "* " e secções', () {
      expect(t.linhas.map((l) => l.texto), [
        'CAFE SOLUVEL 100G',
        'AZEITE VIRGEM 750ML',
        'CHAMPO SUAVE,,900ML',
        'DETERGENTE ROUPA',
      ]);
      expect(t.linhas[1].quantidade, 2);
      expect(t.linhas[1].precoUnitCent, 589);
      expect(t.linhas[1].brutoCent, 1178);
      expect(t.linhas[0].seccao, 'MERCEARIA');
      expect(t.linhas[3].seccao, 'D.P.H');
    });

    test('total; os ganhos do cartão não são desconto', () {
      expect(t.totalCent, 2514);
      expect(t.descontoCompraCent, 0);
      expect(t.bate, isTrue);
    });
  });

  // Texto do OCR de um talão em papel (fictício, com os erros vistos nas
  // fotografias reais): IVA numa linha à parte ou colado, ano da linha
  // "Caixa" estragado, preço unitário ilegível, quantidade em falta.
  group('E.Leclerc em papel (OCR)', () {
    final texto = _f('leclerc_papel');
    final t = lerLeclerc(texto)!;

    test('loja pelo cabeçalho estragado; ano da linha dd/mm/aa', () {
      expect(t.loja, 'E.Leclerc');
      expect(t.local, isNull); // a localidade vem estragada
      expect(t.data, DateTime(2026, 10, 24));
      expect(t.numero, isNull);
    });

    test('linhas sem as linhas do IVA, com o IVA colado e sem quantidade', () {
      expect(t.linhas.map((l) => l.texto), [
        'CAFE SOLUVEL 100G',
        'AZEITE VIRGEM 750HL',
        'BOLACHAS AVEIA 200G',
        'CHAMPO SUAVE 900HL',
        'DETERGENTE ROUPA',
      ]);
      final azeite = t.linhas[1];
      expect(
        (azeite.quantidade, azeite.precoUnitCent, azeite.brutoCent),
        (2, 589, 1178),
      );
      expect(t.linhas.last.quantidade, 1);
      expect(t.linhas[0].seccao, 'NERCEARIA');
      expect(t.linhas.last.seccao, 'D.P.H');
      expect(t.naoReconhecidas, isEmpty);
      expect((t.totalCent, t.bate), (2663, true));
    });

    test('valor ilegível fica por reconhecer e não bate', () {
      final m = lerLeclerc(texto.replaceFirst('200G 1.49 1', '200G .49 1'))!;
      expect(m.naoReconhecidas, ['6 BOLACHAS AVEIA 200G .49 1']);
      expect(m.bate, isFalse);
    });

    test('total com "artigos" estragado pelo OCR', () {
      final m = lerLeclerc(texto.replaceFirst('5 artigos', '5 artigns'))!;
      expect((m.totalCent, m.bate), (2663, true));
    });

    test('sem a linha "Caixa" → sem data', () {
      expect(
        () => lerLeclerc(texto.replaceFirst(RegExp(r'Caixa .*\n'), '')),
        throwsA(isA<FormatException>()),
      );
    });

    test('lerTalao reconhece o papel', () {
      expect(lerTalao(texto)!.loja, 'E.Leclerc');
    });
  });

  group('lerTalao', () {
    test('escolhe o leitor pela loja', () {
      expect(lerTalao(_f('lidl'))!.loja, 'Lidl');
      expect(lerTalao(_f('leclerc'))!.loja, 'E.Leclerc');
      expect(lerTalao(_f('pingo_doce'))!.loja, 'Pingo Doce');
    });

    test('texto sem loja conhecida → null', () {
      expect(lerTalao('CONTINENTE\nTOTAL 1,00'), isNull);
    });
  });
}
