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

  /// Resposta de artigosDoPainel e os pedidos feitos.
  Future<DetalhePainel> Function() detalhe = () async =>
      const DetalhePainel(artigos: [], semArtigoCent: 0, diferencaCent: 0);
  final barras = <BarraPainel>[];

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

  @override
  Future<DetalhePainel> artigosDoPainel(
    FiltroCompras filtro, {
    String? lojaId,
    List<String>? categoriaIds,
    bool semCategoria = false,
    DateTime? hoje,
  }) {
    barras.add(
      BarraPainel(
        filtro: filtro,
        lojaId: lojaId,
        categoriaIds: categoriaIds ?? const [],
        semCategoria: semCategoria,
      ),
    );
    return detalhe();
  }
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
          precosAtuaisProvider.overrideWith((_) => Stream.value(const [])),
          registosPrecoProvider.overrideWith((_, _) => Stream.value(const [])),
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

  group('tocar numa barra (Fase 14)', () {
    const detalheContinente = DetalhePainel(
      artigos: [
        ArtigoDetalhe(
          artigoId: 'a1',
          totalCent: 9000,
          quantidade: 6,
          pesoG: 0,
          nCompras: 2,
        ),
        ArtigoDetalhe(
          artigoId: 'a-apagado',
          totalCent: 1000,
          quantidade: 0,
          pesoG: 1250,
          nCompras: 1,
        ),
      ],
      semArtigoCent: 0,
      diferencaCent: 0,
    );

    Future<_EstatisticasFalsas> abrirFolha(
      WidgetTester t,
      String barra, {
      DetalhePainel detalhe = detalheContinente,
      ResultadoPainel? painel,
      DadosPainel? dados,
    }) async {
      final repo = _EstatisticasFalsas(
        () async => painel ?? ResultadoPainel(dados ?? _dados()),
      )..detalhe = () async => detalhe;
      await abrir(t, repo);
      await t.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(barra)}: ')));
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('loja: folha com título, artigos por ordem do total e total '
        'igual à barra', (t) async {
      final repo = await abrirFolha(t, 'Continente');
      expect(repo.barras.single.lojaId, 'l1');
      expect(repo.barras.single.categoriaIds, isEmpty);
      expect(find.text('Continente · Este mês'), findsOneWidget);
      final folha = find.byType(BottomSheet);
      expect(
        find.descendant(of: folha, matching: find.text('Leite')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: folha, matching: find.text('6 un · 2 compras')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: folha, matching: find.text('Artigo apagado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: folha, matching: find.text('1,250 kg · 1 compra')),
        findsOneWidget,
      );
      expect(
        t
            .getTopLeft(
              find.descendant(of: folha, matching: find.text('Leite')),
            )
            .dy,
        lessThan(
          t
              .getTopLeft(
                find.descendant(
                  of: folha,
                  matching: find.text('Artigo apagado'),
                ),
              )
              .dy,
        ),
      );
      // Total igual ao valor da barra (10000).
      expect(
        find.descendant(of: folha, matching: find.text(formatarCent(10000))),
        findsOneWidget,
      );
      expect(find.textContaining('Linhas sem artigo'), findsNothing);
      expect(find.textContaining('Diferença'), findsNothing);
    });

    testWidgets('linhas sem artigo e diferença só quando não são 0', (t) async {
      await abrirFolha(
        t,
        'Continente',
        detalhe: const DetalhePainel(
          artigos: [
            ArtigoDetalhe(
              artigoId: 'a1',
              totalCent: 9000,
              quantidade: 1,
              pesoG: 0,
              nCompras: 1,
            ),
          ],
          semArtigoCent: 700,
          diferencaCent: 300,
        ),
      );
      expect(find.text('Linhas sem artigo'), findsOneWidget);
      expect(find.text('Diferença do total das compras'), findsOneWidget);
      expect(find.text(formatarCent(700)), findsOneWidget);
      expect(find.text(formatarCent(300)), findsOneWidget);
    });

    testWidgets('categoria e "Sem categoria"', (t) async {
      final repo = await abrirFolha(t, 'Laticínios');
      expect(repo.barras.single.categoriaIds, ['c1']);
      expect(repo.barras.single.semCategoria, isFalse);
      expect(repo.barras.single.lojaId, isNull);
      expect(find.text('Laticínios · Este mês'), findsOneWidget);

      await t.tapAt(const Offset(10, 10)); // fecha a folha
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel(RegExp('^Sem categoria: ')));
      await t.pumpAndSettle();
      expect(repo.barras.last.categoriaIds, isEmpty);
      expect(repo.barras.last.semCategoria, isTrue);
    });

    testWidgets('"Outras": as categorias depois das 8 maiores', (t) async {
      final repo = await abrirFolha(
        t,
        'Outras',
        dados: DadosPainel(
          totalCent: 1000,
          nCompras: 1,
          poupancaCent: 0,
          porMes: [TotalMes(DateTime(2026, 10), 1000, 1)],
          porLoja: const [TotalLoja('l1', 1000, 1)],
          porCategoria: [
            for (var i = 1; i <= 9; i++) TotalCategoria('c$i', 100),
            const TotalCategoria(null, 100),
          ],
          artigos: const [],
        ),
      );
      expect(repo.barras.single.categoriaIds, ['c9']);
      expect(repo.barras.single.semCategoria, isTrue);
      expect(find.text('Outras · Este mês'), findsOneWidget);
    });

    testWidgets('tocar num artigo abre o detalhe do artigo', (t) async {
      await abrirFolha(t, 'Continente');
      await t.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Leite'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('sem rede: mostra a mensagem', (t) async {
      final repo = _EstatisticasFalsas(() async => ResultadoPainel(_dados()))
        ..detalhe = () async =>
            throw const ErroDados('Sem rede: liga-te para ver os artigos.');
      await abrir(t, repo);
      await t.tap(find.bySemanticsLabel(RegExp('^Continente: ')));
      await t.pumpAndSettle();
      expect(
        find.text('Sem rede: liga-te para ver os artigos.'),
        findsOneWidget,
      );
    });

    testWidgets('Painel da cache: a folha avisa que a lista é de agora', (
      t,
    ) async {
      await abrirFolha(
        t,
        'Continente',
        painel: ResultadoPainel(_dados(), guardadoEm: DateTime(2026, 10, 1)),
      );
      expect(
        find.text('O Painel está desatualizado; esta lista é de agora.'),
        findsOneWidget,
      );
    });
  });
}
