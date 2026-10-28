import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/painel/painel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _lojas = [
  Loja(id: 'l1', slug: 'continente', nome: 'Continente', cor: '#eb6834'),
  Loja(id: 'l2', slug: 'lidl', nome: 'Lidl'),
];
const _categorias = [Categoria(id: 'c1', nome: 'Laticínios', ordem: 1)];
const _artigos = [
  Artigo(id: 'a1', nome: 'Leite', categoriaId: 'c1', unidade: Unidade.un),
];

DadosPainel _dados({int nCompras = 3}) => DadosPainel(
  totalCent: 12345,
  nCompras: nCompras,
  poupancaCent: 250,
  porMes: [TotalMes(DateTime(2026, 10), 12345, nCompras)],
  porLoja: const [TotalLoja('l1', 10000, 2), TotalLoja('l2', 2345, 1)],
  porCategoria: const [TotalCategoria('c1', 9000), TotalCategoria(null, 3345)],
  artigos: const [TotalArtigo('a1', 900, 4)],
);

class _EstatisticasFalsas implements EstatisticasRepository {
  _EstatisticasFalsas(this.resposta);

  Future<ResultadoPainel> Function() resposta;
  final filtros = <FiltroCompras>[];

  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) {
    filtros.add(filtro);
    return resposta();
  }

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) async => const [];

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async => const [];
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  Future<void> abrir(
    WidgetTester t,
    _EstatisticasFalsas repo, {
    double largura = 500,
    double menu = 0,
  }) async {
    t.view.physicalSize = Size(largura, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          estatisticasRepositoryProvider.overrideWithValue(repo),
          lojasProvider.overrideWith((_) => Stream.value(_lojas)),
          categoriasProvider.overrideWith((_) => Stream.value(_categorias)),
          artigosProvider.overrideWith((_) => Stream.value(_artigos)),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          // [menu] simula o menu fixo do ecrã largo, ao lado da página.
          home: Row(
            children: [
              SizedBox(width: menu),
              const Expanded(child: PainelPage()),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('mostra os 4 números formatados', (t) async {
    await abrir(t, _EstatisticasFalsas(() async => ResultadoPainel(_dados())));
    expect(find.text(formatarCent(12345)), findsOneWidget);
    expect(find.text(formatarInteiro(3)), findsOneWidget);
    expect(find.text(formatarCent(4115)), findsOneWidget); // 12345 / 3
    expect(find.text(formatarCent(250)), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Sem categoria'), findsOneWidget);
    expect(find.textContaining('sem rede'), findsNothing);
  });

  testWidgets('a 400 px os 4 cartões têm a mesma largura', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados())),
      largura: 400,
    );
    double largura(String titulo) => t
        .getSize(
          find.ancestor(of: find.text(titulo), matching: find.byType(Card)),
        )
        .width;
    expect(largura('Total gasto'), largura('Média por compra'));
    expect(largura('Compras'), largura('Poupança'));
    expect(largura('Total gasto'), largura('Compras'));
  });

  testWidgets('a 360 px os cartões de cada linha têm a mesma altura', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados())),
      largura: 360,
    );
    double altura(String titulo) => t
        .getSize(
          find.ancestor(of: find.text(titulo), matching: find.byType(Card)),
        )
        .height;
    // "Média por compra" passa para duas linhas a esta largura.
    expect(
      t.getSize(find.text('Média por compra')).height,
      greaterThan(t.getSize(find.text('Poupança')).height),
    );
    expect(altura('Média por compra'), altura('Poupança'));
    expect(altura('Total gasto'), altura('Compras'));
  });

  testWidgets('com guardadoEm mostra o aviso sem rede', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(
        () async =>
            ResultadoPainel(_dados(), guardadoEm: DateTime(2026, 10, 24, 9, 5)),
      ),
    );
    expect(
      find.text(
        'Dados de ${formatarData(DateTime(2026, 10, 24))} às 09:05; '
        'sem rede.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mudar o período volta a pedir o painel', (t) async {
    final repo = _EstatisticasFalsas(() async => ResultadoPainel(_dados()));
    await abrir(t, repo);
    expect(repo.filtros.last, (periodo: Periodo.esteMes, lojaId: null));

    await t.tap(find.text('Este mês'));
    await t.pumpAndSettle();
    await t.tap(find.text('Este ano').last);
    await t.pumpAndSettle();
    expect(repo.filtros.last, (periodo: Periodo.esteAno, lojaId: null));
  });

  testWidgets('sem compras mostra a mensagem', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados(nCompras: 0))),
    );
    expect(find.text('Não há compras neste período.'), findsOneWidget);
    expect(find.text('Por loja'), findsNothing);
  });

  testWidgets('erro mostra a mensagem e Tentar outra vez', (t) async {
    final repo = _EstatisticasFalsas(
      () async => throw const ErroDados('Sem rede e sem dados guardados.'),
    );
    await abrir(t, repo);
    expect(find.text('Sem rede e sem dados guardados.'), findsOneWidget);
    expect(find.text('Tentar outra vez'), findsOneWidget);

    repo.resposta = () async => ResultadoPainel(_dados());
    await t.tap(find.text('Tentar outra vez'));
    await t.pumpAndSettle();
    expect(find.text(formatarCent(12345)), findsOneWidget);
  });

  testWidgets('a 1000 px Por loja e Por categoria lado a lado', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados())),
      largura: 1000,
    );
    expect(
      t.getTopLeft(find.text('Por loja')).dy,
      t.getTopLeft(find.text('Por categoria')).dy,
    );
  });

  testWidgets('ecrã largo mas pouco espaço ao lado do menu: em coluna', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados())),
      largura: 900,
      menu: 400,
    );
    expect(
      t.getTopLeft(find.text('Por categoria')).dy,
      greaterThan(t.getTopLeft(find.text('Por loja')).dy),
    );
  });

  testWidgets('a 400 px Por loja e Por categoria em coluna', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => ResultadoPainel(_dados())),
      largura: 400,
    );
    expect(
      t.getTopLeft(find.text('Por categoria')).dy,
      greaterThan(t.getTopLeft(find.text('Por loja')).dy),
    );
  });
}
