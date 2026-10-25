import 'package:cabaz_mensal/data/local/repositorios_locais.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Artigo', () {
    test('toMap/fromMap com e sem ean', () {
      for (final ean in ['4006381333931', null]) {
        final a = Artigo(
          id: 'a1',
          nome: 'Leite',
          categoriaId: null,
          unidade: Unidade.un,
          ean: ean,
        );
        expect(Artigo.fromMap(a.toMap()).ean, ean);
      }
    });

    test('lê um JSON antigo sem a chave ean', () {
      final a = Artigo.fromMap({
        'id': 'a1',
        'nome': 'Leite',
        'categoria_id': null,
        'unidade': 'un',
        'ativo': true,
      });
      expect(a.ean, isNull);
    });
  });

  test('precosAtuaisDe: preços registados e nunca desatualizados', () {
    final p = precosAtuaisDe([
      {
        'artigo_id': 'a1',
        'loja_id': 'l1',
        'data': '2026-10-01',
        'preco_cent': 129,
        'criado_em': '2026-10-01T10:00:00Z',
      },
    ]).single;
    expect(p.fonte, FontePreco.registado);
    expect(p.desatualizado, isFalse);
  });
}
