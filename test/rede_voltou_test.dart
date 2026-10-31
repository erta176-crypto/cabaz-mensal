import 'dart:async';

import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _dados = DadosPainel(
  totalCent: 100,
  nCompras: 1,
  poupancaCent: 0,
  porMes: [],
  porLoja: [],
  porCategoria: [],
  artigos: [],
);

/// Cada pedido usa a próxima resposta da fila (null = sem rede).
class _Estatisticas implements EstatisticasRepository {
  final paineis = <ResultadoPainel?>[];
  final linhasRespostas = <List<LinhaCompra>?>[];
  int pedidosPainel = 0;
  int pedidosLinhas = 0;

  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) async {
    pedidosPainel++;
    return paineis.removeAt(0) ?? (throw const ErroDados('Sem rede.'));
  }

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) async => const [];

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async {
    pedidosLinhas++;
    return linhasRespostas.removeAt(0) ?? (throw const ErroDados('Sem rede.'));
  }
}

void main() {
  late _Estatisticas est;
  late StreamController<EstadoSync> sync;
  late ProviderContainer c;
  const filtro = (periodo: Periodo.esteMes, lojaId: null);

  setUp(() {
    est = _Estatisticas();
    sync = StreamController<EstadoSync>();
    c = ProviderContainer(
      overrides: [
        estatisticasRepositoryProvider.overrideWithValue(est),
        estadoSyncProvider.overrideWith((_) => sync.stream),
      ],
    );
    addTearDown(() {
      c.dispose();
      sync.close();
    });
  });

  Future<void> rede(bool online) async {
    sync.add(EstadoSync(online: online));
    await pumpEventQueue();
  }

  Future<AsyncValue<ResultadoPainel>> painel() async {
    c.listen(painelProvider(filtro), (_, _) {});
    await pumpEventQueue();
    return c.read(painelProvider(filtro));
  }

  test('erro sem rede: quando a rede volta, pede outra vez', () async {
    await rede(false);
    est.paineis.addAll([null, const ResultadoPainel(_dados)]);
    expect((await painel()).hasError, isTrue);

    await rede(true);
    expect(est.pedidosPainel, 2);
    expect(c.read(painelProvider(filtro)).value?.guardadoEm, isNull);
  });

  test('dados da cache: quando a rede volta, pede outra vez', () async {
    await rede(false);
    est.paineis.addAll([
      ResultadoPainel(_dados, guardadoEm: DateTime(2026, 10, 30)),
      const ResultadoPainel(_dados),
    ]);
    expect((await painel()).value?.guardadoEm, isNotNull);

    await rede(true);
    expect(est.pedidosPainel, 2);
    expect(c.read(painelProvider(filtro)).value?.guardadoEm, isNull);
  });

  test('dados frescos: a rede ir e voltar não pede outra vez', () async {
    await rede(true);
    est.paineis.add(const ResultadoPainel(_dados));
    expect((await painel()).hasValue, isTrue);

    await rede(false);
    await rede(true);
    expect(est.pedidosPainel, 1);
  });

  test('linhas da compra: erro sem rede, pede outra vez', () async {
    await rede(false);
    est.linhasRespostas.addAll([null, const []]);
    c.listen(linhasCompraProvider('c1'), (_, _) {});
    await pumpEventQueue();
    expect(c.read(linhasCompraProvider('c1')).hasError, isTrue);

    await rede(true);
    expect(est.pedidosLinhas, 2);
    expect(c.read(linhasCompraProvider('c1')).value, isEmpty);
  });
}
