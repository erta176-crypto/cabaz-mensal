import 'dart:io';
import 'dart:math';

import 'package:cabaz_mensal/import/taloes/leclerc.dart';
import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Caixa de 30 px de altura com o canto superior esquerdo em (x, y).
CaixaOcr _caixa(String t, double x, double y, {double angulo = 0}) => CaixaOcr(
  texto: t,
  esquerda: x,
  cima: y,
  direita: x + t.length * 15,
  baixo: y + 30,
  angulo: angulo,
);

void main() {
  group('linhasDasCaixas', () {
    test('descrição e preço em caixas separadas dão uma linha', () {
      expect(
        linhasDasCaixas([
          _caixa('1,19 A', 600, 102),
          _caixa('BOLACHAS INTEGRAIS', 20, 100),
          _caixa('LEITE MEIO GORDO', 20, 140),
          _caixa('9,84 B', 600, 138),
        ]),
        'BOLACHAS INTEGRAIS 1,19 A\nLEITE MEIO GORDO 9,84 B',
      );
    });

    test('três colunas na mesma linha, ordenadas da esquerda para a '
        'direita', () {
      expect(
        linhasDasCaixas([
          _caixa('1,80 D', 600, 100),
          _caixa('2 DEO ROLL-ON ALOE', 20, 100),
          _caixa('0,90', 420, 101),
        ]),
        '2 DEO ROLL-ON ALOE 0,90 1,80 D',
      );
    });

    test('talão inclinado (−2°): o preço à direita fica mais acima mas na '
        'mesma linha', () {
      // A −2°, 600 px para a direita sobem ≈ 21 px (mais de meia linha).
      final sobe = 600 * tan(2 * pi / 180);
      expect(
        linhasDasCaixas([
          _caixa('PAPRIKA', 0, 100, angulo: -2),
          _caixa('2,50 D', 600, 100 - sobe, angulo: -2),
          _caixa('DORMIR', 0, 140, angulo: -2),
          _caixa('1,20 D', 600, 140 - sobe, angulo: -2),
        ]),
        'PAPRIKA 2,50 D\nDORMIR 1,20 D',
      );
    });

    test('linhas seguidas (32 px de distância) não se juntam', () {
      expect(
        linhasDasCaixas([
          _caixa('MILHO DOCE', 20, 100),
          _caixa('2 x 1,09', 40, 132),
        ]),
        'MILHO DOCE\n2 x 1,09',
      );
    });

    test('sem caixas, texto vazio', () {
      expect(linhasDasCaixas(const []), '');
    });
  });

  group('normalizarOcr', () {
    test('espaço depois da vírgula nos números', () {
      expect(normalizarOcr('2 x 1, 09'), '2 x 1,09');
    });

    test('vezes em maiúscula ou colado', () {
      expect(normalizarOcr('2 X 0,89'), '2 x 0,89');
      expect(normalizarOcr('2 X0,89'), '2 x 0,89');
      expect(normalizarOcr('3 x0, 85'), '3 x 0,85');
    });

    test('EUR/Kg', () {
      expect(normalizarOcr('1,258 kg x 1,25 EUR/Kg'), '1,258 kg x 1,25 EUR/kg');
    });

    test('ponto em vez de vírgula só no valor com a letra do IVA', () {
      expect(normalizarOcr('2 TOPPING 1,85 3.70 D'), '2 TOPPING 1,85 3,70 D');
      expect(normalizarOcr('Total 3.70'), 'Total 3.70');
    });

    test('espaços repetidos', () {
      expect(
        normalizarOcr('PEITO  DE   FRANGO 1,95 A'),
        'PEITO DE FRANGO 1,95 A',
      );
    });

    test('não mexe em datas, horas nem moradas', () {
      const texto =
          'Data de Venda: 2024-09-22\n'
          '2024-09-22 11:25:27 Per063\n'
          '26-06-04 18:56:36\n'
          'Rua Inventada 18, Vila Ficticia';
      expect(normalizarOcr(texto), texto);
    });

    test('as linhas do E.Leclerc (ponto decimal) ficam iguais e lidas', () {
      final texto = File('test/fixtures/taloes/leclerc.txt')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      final antes = lerLeclerc(texto)!;
      final depois = lerLeclerc(normalizarOcr(texto))!;
      expect(depois.linhas.length, antes.linhas.length);
      expect(depois.totalCent, antes.totalCent);
      expect(
        [for (final l in depois.linhas) l.brutoCent],
        [for (final l in antes.linhas) l.brutoCent],
      );
    });
  });
}
