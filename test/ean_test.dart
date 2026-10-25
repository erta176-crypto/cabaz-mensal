import 'package:cabaz_mensal/domain/ean.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarEan', () {
    test('aceita EAN-8, EAN-13 e GTIN-14 válidos', () {
      expect(normalizarEan('73513537'), '73513537');
      expect(normalizarEan('4006381333931'), '4006381333931');
      expect(normalizarEan('00012345600012'), '00012345600012');
    });

    test('UPC-A (12 dígitos) passa a EAN-13 com um 0 à frente', () {
      expect(normalizarEan('036000291452'), '0036000291452');
      expect(normalizarEan('036000291452'), normalizarEan('0036000291452'));
    });

    test('tira os espaços', () {
      expect(normalizarEan(' 4006381 333931 '), '4006381333931');
    });

    test('recusa o dígito de controlo errado', () {
      expect(normalizarEan('4006381333932'), isNull);
      expect(normalizarEan('73513530'), isNull);
    });

    test('recusa letras, vazio e comprimentos inválidos', () {
      expect(normalizarEan('40063813339A1'), isNull);
      expect(normalizarEan(''), isNull);
      expect(normalizarEan('123'), isNull);
      expect(normalizarEan('12345678901'), isNull);
    });
  });
}
