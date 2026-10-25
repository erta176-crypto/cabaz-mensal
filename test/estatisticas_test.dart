import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _jsonPainel() => {
  'total_cent': 5000,
  'n_compras': 3,
  'poupanca_cent': 250,
  'por_mes': [
    {'mes': '2026-09', 'total_cent': 2000, 'n_compras': 1},
    {'mes': '2026-10', 'total_cent': 3000, 'n_compras': 2},
  ],
  'por_loja': [
    {'loja_id': 'l1', 'total_cent': 3500, 'n_compras': 2},
    {'loja_id': 'l2', 'total_cent': 1500, 'n_compras': 1},
  ],
  'por_categoria': [
    {'categoria_id': 'c1', 'total_cent': 4000},
    {'categoria_id': null, 'total_cent': 1000},
  ],
  'artigos': [
    {'artigo_id': 'a1', 'total_cent': 900, 'n_linhas': 4},
  ],
};

DadosPainel _painel({required int totalCent, required int nCompras}) =>
    DadosPainel(
      totalCent: totalCent,
      nCompras: nCompras,
      poupancaCent: 0,
      porMes: const [],
      porLoja: const [],
      porCategoria: const [],
      artigos: const [],
    );

CompraResumo _compra(String id, DateTime data, int totalCent) => CompraResumo(
  id: id,
  lojaId: 'l1',
  data: data,
  totalCent: totalCent,
  poupancaCent: 0,
  origem: 'manual',
  rever: false,
  nLinhas: 1,
);

void main() {
  group('intervaloDe', () {
    final hoje = DateTime(2026, 10, 25);

    test('os 5 períodos a 2026-10-25', () {
      expect(intervaloDe(Periodo.esteMes, hoje), (
        de: DateTime(2026, 10, 1),
        ate: hoje,
      ));
      expect(intervaloDe(Periodo.ultimos3Meses, hoje), (
        de: DateTime(2026, 8, 1),
        ate: hoje,
      ));
      expect(intervaloDe(Periodo.ultimos12Meses, hoje), (
        de: DateTime(2025, 11, 1),
        ate: hoje,
      ));
      expect(intervaloDe(Periodo.esteAno, hoje), (
        de: DateTime(2026, 1, 1),
        ate: hoje,
      ));
      expect(intervaloDe(Periodo.tudo, hoje), (
        de: DateTime(2000, 1, 1),
        ate: hoje,
      ));
    });

    test('só a data conta: a hora de hoje é ignorada', () {
      final r = intervaloDe(Periodo.esteMes, DateTime(2026, 10, 25, 18, 30));
      expect(r.ate, DateTime(2026, 10, 25));
    });

    test('viragem de ano nos últimos 3 e 12 meses', () {
      final jan = DateTime(2026, 1, 15);
      expect(intervaloDe(Periodo.ultimos3Meses, jan).de, DateTime(2025, 11, 1));
      expect(intervaloDe(Periodo.ultimos12Meses, jan).de, DateTime(2025, 2, 1));
      final fev = DateTime(2026, 2, 28);
      expect(intervaloDe(Periodo.ultimos3Meses, fev).de, DateTime(2025, 12, 1));
      expect(intervaloDe(Periodo.ultimos12Meses, fev).de, DateTime(2025, 3, 1));
    });

    test('de é sempre dia 1, exceto em tudo', () {
      for (final p in Periodo.values.where((p) => p != Periodo.tudo)) {
        expect(intervaloDe(p, DateTime(2026, 2, 28)).de.day, 1);
      }
    });
  });

  group('DadosPainel', () {
    test('fromJson → toJson devolve o mapa original', () {
      final j = _jsonPainel();
      expect(DadosPainel.fromJson(j).toJson(), j);
    });

    test('fromJson lê os campos e a categoria null', () {
      final d = DadosPainel.fromJson(_jsonPainel());
      expect(d.totalCent, 5000);
      expect(d.nCompras, 3);
      expect(d.poupancaCent, 250);
      expect(d.porMes.first.mes, DateTime(2026, 9, 1));
      expect(d.porMes.last.nCompras, 2);
      expect(d.porLoja.first.lojaId, 'l1');
      expect(d.porCategoria.last.categoriaId, isNull);
      expect(d.artigos.single.nLinhas, 4);
    });

    test('aceita números como num (12.0)', () {
      final j = _jsonPainel()
        ..['total_cent'] = 12.0
        ..['n_compras'] = 2.0;
      final d = DadosPainel.fromJson(j);
      expect(d.totalCent, 12);
      expect(d.nCompras, 2);
    });

    test('mediaCent arredonda e é 0 sem compras', () {
      expect(_painel(totalCent: 1000, nCompras: 3).mediaCent, 333);
      expect(_painel(totalCent: 1001, nCompras: 2).mediaCent, 501);
      expect(_painel(totalCent: 0, nCompras: 0).mediaCent, 0);
    });
  });

  group('mesesCompletos', () {
    test('preenche com zeros os meses sem compras, por ordem', () {
      final r = mesesCompletos(
        [TotalMes(DateTime(2026, 9, 1), 2000, 1)],
        DateTime(2026, 8, 1),
        DateTime(2026, 10, 25),
      );
      expect(r.map((m) => m.mes), [
        DateTime(2026, 8, 1),
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      ]);
      expect(r.map((m) => m.totalCent), [0, 2000, 0]);
      expect(r.map((m) => m.nCompras), [0, 1, 0]);
    });

    test('atravessa a viragem de ano', () {
      final r = mesesCompletos(
        const [],
        DateTime(2025, 11, 1),
        DateTime(2026, 2, 3),
      );
      expect(r.length, 4);
      expect(r.last.mes, DateTime(2026, 2, 1));
    });
  });

  group('categoriasTopo', () {
    List<TotalCategoria> cats(int n) => [
      for (var i = 0; i < n; i++) TotalCategoria('c$i', (n - i) * 100),
    ];

    test('10 categorias, n=8: 8 no topo e as 2 últimas em outras', () {
      final r = categoriasTopo(cats(10));
      expect(r.topo.length, 8);
      expect(r.topo.first.categoriaId, 'c0');
      expect(r.outrasCent, 200 + 100);
    });

    test('3 categorias: sem resto', () {
      final r = categoriasTopo(cats(3));
      expect(r.topo.length, 3);
      expect(r.outrasCent, 0);
    });
  });

  group('fromMap', () {
    test('CompraResumo com campos opcionais a null', () {
      final c = CompraResumo.fromMap({
        'id': 'c1',
        'loja_id': 'l1',
        'data': '2026-10-25',
        'local': null,
        'total_cent': 1234,
        'poupanca_cent': 0,
        'origem': 'lista',
        'rever': false,
        'n_linhas': 7,
      });
      expect(c.data, DateTime(2026, 10, 25));
      expect(c.local, isNull);
      expect(c.totalCent, 1234);
      expect(c.nLinhas, 7);
    });

    test('LinhaCompra com campos opcionais a null', () {
      final l = LinhaCompra.fromMap({
        'id': 'x1',
        'compra_id': 'c1',
        'artigo_id': null,
        'texto_original': null,
        'quantidade': null,
        'peso_g': null,
        'preco_unit_cent': null,
        'bruto_cent': 500,
        'desconto_cent': 50,
        'pago_cent': 450,
      });
      expect(l.artigoId, isNull);
      expect(l.textoOriginal, isNull);
      expect(l.quantidade, isNull);
      expect(l.pesoG, isNull);
      expect(l.precoUnitCent, isNull);
      expect(l.pagoCent, 450);
    });

    test('LinhaCompra com todos os campos', () {
      final l = LinhaCompra.fromMap({
        'id': 'x1',
        'compra_id': 'c1',
        'artigo_id': 'a1',
        'texto_original': 'LEITE UHT',
        'quantidade': 6,
        'peso_g': 1200,
        'preco_unit_cent': 80,
        'bruto_cent': 480,
        'desconto_cent': 0,
        'pago_cent': 480,
      });
      expect(l.artigoId, 'a1');
      expect(l.quantidade, 6);
      expect(l.pesoG, 1200);
      expect(l.precoUnitCent, 80);
    });

    test('RegistoPreco.fromMap é o inverso de toMap', () {
      final r = RegistoPreco(
        id: 'r1',
        artigoId: 'a1',
        lojaId: 'l1',
        data: DateTime(2026, 10, 25),
        precoCent: 199,
        origem: OrigemPreco.talao,
      );
      final lido = RegistoPreco.fromMap(r.toMap());
      expect(lido.toMap(), r.toMap());
      expect(lido.origem, OrigemPreco.talao);
      expect(lido.data, DateTime(2026, 10, 25));
    });
  });

  group('porMes', () {
    test('agrupa por mês mantendo a ordem e somando os totais', () {
      final r = porMes([
        _compra('a', DateTime(2026, 10, 20), 1000),
        _compra('b', DateTime(2026, 10, 2), 500),
        _compra('c', DateTime(2026, 9, 28), 700),
      ]);
      expect(r.length, 2);
      expect(r[0].mes, DateTime(2026, 10, 1));
      expect(r[0].compras.map((c) => c.id), ['a', 'b']);
      expect(r[0].totalCent, 1500);
      expect(r[1].mes, DateTime(2026, 9, 1));
      expect(r[1].totalCent, 700);
    });

    test('lista vazia dá lista vazia', () {
      expect(porMes(const []), isEmpty);
    });
  });
}
