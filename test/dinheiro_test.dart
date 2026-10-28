import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/domain/dinheiro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  group('eurosParaCent', () {
    test('0,1 + 0,2 dá 30 cêntimos (sem erro de vírgula flutuante)', () {
      expect(0.1 + 0.2, isNot(0.3)); // o problema que estamos a evitar
      expect(eurosParaCent(0.1 + 0.2), 30);
    });

    test('total do histórico', () {
      expect(eurosParaCent(4652.26), 465226);
    });

    test('somar cêntimos, nunca doubles', () {
      final valores = List.filled(10, 0.1);
      final cent = valores.map(eurosParaCent).fold(0, (s, v) => s + v);
      expect(cent, 100);
    });
  });

  test('kgParaG arredonda pesos com ruído de vírgula flutuante', () {
    expect(kgParaG(0.794), 794);
    expect(kgParaG(1.005), 1005);
    expect(kgParaG(2.35), 2350);
  });

  group('centDeTexto', () {
    test('formatos pt-PT e com ponto', () {
      expect(centDeTexto('1,29'), 129);
      expect(centDeTexto('1.29'), 129);
      expect(centDeTexto('1 234,50 €'), 123450);
      expect(centDeTexto('1.234,50'), 123450);
      expect(centDeTexto('2'), 200);
    });

    test('vazio ou inválido devolve null', () {
      expect(centDeTexto(''), isNull);
      expect(centDeTexto('abc'), isNull);
      expect(centDeTexto('-1'), isNull);
    });
  });

  group('precoUnitarioCent', () {
    test('por unidade', () {
      expect(precoUnitarioCent(brutoCent: 249, quantidade: 2), 125);
      expect(precoUnitarioCent(brutoCent: 249, quantidade: 1), 249);
    });

    test('por quilo nas linhas ao peso', () {
      expect(precoUnitarioCent(brutoCent: 174, pesoG: 794), 219);
    });

    test('sem quantidade nem peso', () {
      expect(precoUnitarioCent(brutoCent: 100), isNull);
    });
  });

  test('formatação em euros pt-PT', () {
    expect(formatarCent(129), '1,29 €');
    expect(formatarCent(465226), matches(RegExp(r'^4\s?652,26\s€$')));
    expect(centParaCampo(129), '1,29');
    expect(centParaCampo(5), '0,05');
  });

  test('gDeTexto: quilos escritos à mão em gramas', () {
    expect(gDeTexto('0,338'), 338);
    expect(gDeTexto(' 1.2 '), 1200);
    expect(gDeTexto('0'), isNull);
    expect(gDeTexto(''), isNull);
    expect(gDeTexto('abc'), isNull);
  });
}
