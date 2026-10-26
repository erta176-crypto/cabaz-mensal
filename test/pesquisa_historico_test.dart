import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/historico/pesquisa.dart';
import 'package:flutter_test/flutter_test.dart';

const _artigos = [
  Artigo(id: 'm1', nome: 'Maçã Gala', categoriaId: null, unidade: Unidade.kg),
  Artigo(
    id: 'l1',
    nome: 'Leite',
    categoriaId: null,
    unidade: Unidade.un,
    ean: '5601234567890',
  ),
  Artigo(id: 'p1', nome: 'Pão', categoriaId: null, unidade: Unidade.un),
];

const _aliases = {
  'l1': ['LEITE UHT MG'],
  'p1': ['CARCAÇA'],
};

void main() {
  test('sem acentos: "maca" encontra "Maçã Gala"', () {
    final r = termosPesquisa('maca', _artigos, _aliases);
    expect(r.artigoIds, ['m1']);
    expect(r.texto, 'maca');
  });

  test('pelo texto do talão (alias)', () {
    expect(termosPesquisa('uht', _artigos, _aliases).artigoIds, ['l1']);
    expect(termosPesquisa('carcaca', _artigos, _aliases).artigoIds, ['p1']);
  });

  test('pelo EAN parcial', () {
    expect(termosPesquisa('560123', _artigos, _aliases).artigoIds, ['l1']);
  });

  test('o mesmo artigo não se repete', () {
    expect(termosPesquisa('leite', _artigos, _aliases).artigoIds, ['l1']);
  });

  test('o texto é enviado com trim', () {
    final r = termosPesquisa('  Iogurte ', _artigos, _aliases);
    expect(r.artigoIds, isEmpty);
    expect(r.texto, 'Iogurte');
  });

  test('texto vazio: sem artigos e texto null', () {
    for (final t in ['', '   ']) {
      final r = termosPesquisa(t, _artigos, _aliases);
      expect(r.artigoIds, isEmpty);
      expect(r.texto, isNull);
    }
  });
}
