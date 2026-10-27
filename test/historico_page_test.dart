import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/historico/detalhe_compra.dart';
import 'package:cabaz_mensal/features/historico/historico_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _lojas = [
  Loja(id: 'l1', slug: 'continente', nome: 'Continente', cor: '#eb6834'),
  Loja(id: 'l2', slug: 'lidl', nome: 'Lidl'),
];
const _artigos = [
  Artigo(id: 'm1', nome: 'Maçã', categoriaId: null, unidade: Unidade.kg),
];

CompraResumo _compra(String id, String loja, DateTime data, int cent) =>
    CompraResumo(
      id: id,
      lojaId: loja,
      data: data,
      totalCent: cent,
      poupancaCent: 0,
      origem: 'talao',
      rever: false,
      nLinhas: 3,
    );

final _compras = [
  _compra('c1', 'l1', DateTime(2026, 10, 20), 4000),
  _compra('c2', 'l2', DateTime(2026, 10, 5), 1500),
  _compra('c3', 'l1', DateTime(2026, 9, 28), 2000),
];

class _EstatisticasFalsas implements EstatisticasRepository {
  _EstatisticasFalsas(this.resposta);

  Future<List<CompraResumo>> Function() resposta;
  final pedidos =
      <({FiltroCompras filtro, List<String>? ids, String? texto})>[];

  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) =>
      throw UnimplementedError();

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) {
    pedidos.add((filtro: filtro, ids: artigoIds, texto: texto));
    return resposta();
  }

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async => const [];
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  Future<void> abrir(
    WidgetTester t,
    _EstatisticasFalsas repo, {
    double largura = 400,
    double altura = 1600,
    double menu = 0,
  }) async {
    t.view.physicalSize = Size(largura, altura);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          estatisticasRepositoryProvider.overrideWithValue(repo),
          lojasProvider.overrideWith((_) => Stream.value(_lojas)),
          artigosProvider.overrideWith((_) => Stream.value(_artigos)),
          aliasesProvider.overrideWith((_) => Stream.value(const {})),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          // [menu] simula o menu fixo do ecrã largo, ao lado da página.
          home: Row(
            children: [
              SizedBox(width: menu),
              const Expanded(child: HistoricoPage()),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('agrupa por mês com o cabeçalho certo', (t) async {
    final repo = _EstatisticasFalsas(() async => _compras);
    await abrir(t, repo);
    expect(repo.pedidos.single.filtro, (
      periodo: Periodo.ultimos12Meses,
      lojaId: null,
    ));
    expect(
      find.text('outubro de 2026 · 2 compras · ${formatarCent(5500)}'),
      findsOneWidget,
    );
    expect(
      find.text('setembro de 2026 · 1 compra · ${formatarCent(2000)}'),
      findsOneWidget,
    );
    expect(find.text('Lidl'), findsWidgets);
  });

  testWidgets('escrever "maca" e esperar 400 ms envia o id da Maçã', (t) async {
    final repo = _EstatisticasFalsas(() async => _compras);
    await abrir(t, repo);
    await t.enterText(find.byType(TextField), 'maca');
    await t.pump(const Duration(milliseconds: 300));
    expect(repo.pedidos, hasLength(1));
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    expect(repo.pedidos.last.ids, ['m1']);
    expect(repo.pedidos.last.texto, 'maca');
  });

  testWidgets('sem resultados com pesquisa', (t) async {
    final repo = _EstatisticasFalsas(() async => const []);
    await abrir(t, repo);
    expect(find.text('Não há compras neste período.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'xyz');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('Nenhuma compra encontrada.'), findsOneWidget);
  });

  testWidgets('a 400 px tocar numa compra abre o DetalheCompraPage', (t) async {
    await abrir(t, _EstatisticasFalsas(() async => _compras));
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsOneWidget);
  });

  testWidgets('a 1000 px o detalhe aparece ao lado', (t) async {
    await abrir(t, _EstatisticasFalsas(() async => _compras), largura: 1000);
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsNothing);
    expect(find.byType(DetalheCompra), findsOneWidget);
    expect(find.byType(HistoricoPage), findsOneWidget);
  });

  testWidgets('ecrã largo mas pouco espaço ao lado do menu: uma coluna', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => _compras),
      largura: 900,
      altura: 600,
      menu: 380,
    );
    expect(t.takeException(), isNull);
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsOneWidget);
  });

  testWidgets('deitado com o teclado aberto (475×200): sem transbordos', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => _compras),
      largura: 475,
      altura: 200,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('erro sem rede mostra a mensagem', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(
        () async =>
            throw const ErroDados('Sem rede: o histórico precisa do servidor.'),
      ),
    );
    expect(
      find.text('Sem rede: o histórico precisa do servidor.'),
      findsOneWidget,
    );
    expect(find.text('Tentar outra vez'), findsOneWidget);
  });
}
