import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/orcamento.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

DadosPainel _gasto({
  required int totalCent,
  List<TotalCategoria> porCategoria = const [],
}) => DadosPainel(
  totalCent: totalCent,
  nCompras: 1,
  poupancaCent: 0,
  porMes: const [],
  porLoja: const [],
  porCategoria: porCategoria,
  artigos: const [],
);

Orcamento _orc(String? categoria, int cent) => Orcamento(
  id: idOrcamento('u1', DateTime(2026, 10), categoria),
  mes: DateTime(2026, 10),
  categoriaId: categoria,
  valorCent: cent,
);

void main() {
  group('idOrcamento', () {
    final out = DateTime(2026, 10);

    test('igual para os mesmos dados (mesmo noutro dia do mês)', () {
      expect(
        idOrcamento('u1', out, 'c1'),
        idOrcamento('u1', DateTime(2026, 10, 25), 'c1'),
      );
      expect(idOrcamento('u1', out, null), idOrcamento('u1', out, null));
    });

    test('diferente para utilizador, mês ou categoria diferentes', () {
      final base = idOrcamento('u1', out, 'c1');
      expect(idOrcamento('u2', out, 'c1'), isNot(base));
      expect(idOrcamento('u1', DateTime(2026, 11), 'c1'), isNot(base));
      expect(idOrcamento('u1', out, 'c2'), isNot(base));
      expect(idOrcamento('u1', out, null), isNot(base));
    });

    test('é um UUID válido', () {
      expect(
        Uuid.isValidUUID(fromString: idOrcamento('u1', out, null)),
        isTrue,
      );
    });
  });

  test('nivel nas fronteiras', () {
    expect(nivel(7900, 10000), NivelOrcamento.ok);
    expect(nivel(8000, 10000), NivelOrcamento.quase);
    expect(nivel(10000, 10000), NivelOrcamento.quase);
    expect(nivel(10001, 10000), NivelOrcamento.passou);
    expect(nivel(0, 0), NivelOrcamento.ok);
    expect(nivel(1, 0), NivelOrcamento.passou);
  });

  test('compararOrcamento: total e categorias com orçamento', () {
    final r = compararOrcamento(
      [_orc(null, 50000), _orc('c1', 10000), _orc('c2', 5000)],
      _gasto(
        totalCent: 42000,
        porCategoria: const [
          TotalCategoria('c1', 11000),
          TotalCategoria('c3', 3000), // sem orçamento: não entra
        ],
      ),
    );
    expect(r.total!.orcamentoCent, 50000);
    expect(r.total!.gastoCent, 42000);
    expect(r.total!.faltaCent, 8000);
    expect(r.total!.nivel, NivelOrcamento.quase);

    expect(r.categorias.map((c) => c.categoriaId), ['c1', 'c2']);
    expect(r.categorias[0].faltaCent, -1000);
    expect(r.categorias[0].nivel, NivelOrcamento.passou);
    expect(r.categorias[1].gastoCent, 0);
    expect(r.categorias[1].nivel, NivelOrcamento.ok);
  });

  test('compararOrcamento sem total', () {
    final r = compararOrcamento([_orc('c1', 1000)], _gasto(totalCent: 500));
    expect(r.total, isNull);
    expect(r.categorias, hasLength(1));
  });

  test('fromMap/toMap ida e volta', () {
    final o = _orc('c1', 1234);
    final m = o.toMap();
    expect(m['mes'], '2026-10-01');
    expect(Orcamento.fromMap(m).toMap(), m);
    expect(Orcamento.fromMap(_orc(null, 1).toMap()).categoriaId, isNull);
  });
}
