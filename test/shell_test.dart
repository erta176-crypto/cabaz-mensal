import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/shell/filtro_pilula.dart';
import 'package:cabaz_mensal/features/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(
  String inicial, {
  Widget? acaoMenu,
  Brightness brilho = Brightness.light,
}) {
  final router = GoRouter(
    initialLocation: inicial,
    routes: [
      ShellRoute(
        builder: (_, estado, filho) => AppShell(
          localizacao: estado.matchedLocation,
          acaoMenu: acaoMenu,
          child: filho,
        ),
        routes: [
          for (final d in destinos)
            GoRoute(
              path: d.caminho,
              builder: (_, _) => Pagina(
                titulo: d.rotuloCurto,
                corpo: Text('pagina ${d.caminho}'),
              ),
            ),
        ],
      ),
    ],
  );
  return MaterialApp.router(
    theme: construirTema(brilho, fontesGoogle: false),
    routerConfig: router,
  );
}

Future<void> _tamanho(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('telemóvel (< 800 px): barra inferior com 4 e ☰ com 6', (
    tester,
  ) async {
    await _tamanho(tester, 400);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing, reason: 'fechado');

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDrawerDestination), findsNWidgets(6));

    await tester.tap(find.text('Importar e exportar'));
    await tester.pumpAndSettle();
    expect(find.text('pagina /importar'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('telemóvel: a barra inferior navega', (tester) async {
    await _tamanho(tester, 400);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artigos'));
    await tester.pumpAndSettle();
    expect(find.text('pagina /artigos'), findsOneWidget);
  });

  testWidgets('ecrã largo (≥ 800 px): menu fixo, sem barra nem ☰', (
    tester,
  ) async {
    await _tamanho(tester, 1200);
    await tester.pumpWidget(_app('/artigos'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byType(NavigationDrawerDestination), findsNWidgets(6));

    await tester.tap(find.text('Definições'));
    await tester.pumpAndSettle();
    expect(find.text('pagina /definicoes'), findsOneWidget);
  });

  testWidgets('telemóvel deitado com a barra do sistema à direita: menu sem '
      'transbordos', (tester) async {
    tester.view.physicalSize = const Size(820, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 48);
    tester.view.viewPadding = const FakeViewPadding(right: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final escala in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets(
      'telemóvel deitado (820×360, recorte à esquerda, letra ×$escala): '
      'menu sem transbordos',
      (tester) async {
        tester.view.physicalSize = const Size(820, 360);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        // Telemóvel deitado: o recorte da câmara fica de um dos lados.
        tester.view.padding = const FakeViewPadding(left: 45);
        tester.view.viewPadding = const FakeViewPadding(left: 45);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          _app(
            '/lista',
            acaoMenu: const IconButton(
              onPressed: null,
              icon: Icon(Icons.dark_mode),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Painel e estatísticas é o primeiro destino', () {
    expect(destinos.first.caminho, '/painel');
    expect(destinosBarraInferior.first.caminho, '/painel');
  });

  testWidgets('o corte é exatamente nos 800 px', (tester) async {
    await _tamanho(tester, 799);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await _tamanho(tester, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });

  for (final brilho in Brightness.values) {
    testWidgets('cabeçalho em gradiente do CoresCabaz (${brilho.name})', (
      tester,
    ) async {
      await _tamanho(tester, 400);
      await tester.pumpWidget(_app('/lista', brilho: brilho));
      await tester.pumpAndSettle();
      final cores = brilho == Brightness.light
          ? CoresCabaz.claro
          : CoresCabaz.escuro;

      final caixa = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CabecalhoPagina),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).gradient is LinearGradient,
          ),
        ),
      );
      final gradiente =
          (caixa.decoration as BoxDecoration).gradient! as LinearGradient;
      // O gradiente tem de ocupar o cabeçalho todo (na T2 um DecoratedBox
      // sem filho ficou com altura 0 dentro do AppBar).
      expect(
        tester.getSize(find.byWidget(caixa)),
        tester.getSize(find.byType(CabecalhoPagina)),
      );
      expect(tester.getSize(find.byWidget(caixa)).height, greaterThan(56));
      expect(gradiente.colors, [cores.gradienteInicio, cores.gradienteFim]);

      final titulo = tester.widget<Text>(
        find.descendant(
          of: find.byType(CabecalhoPagina),
          matching: find.text('Lista'),
        ),
      );
      expect(titulo.style?.color, cores.sobreGradiente);

      expect(
        tester.getSize(find.widgetWithIcon(IconButton, Icons.menu)).width,
        greaterThanOrEqualTo(48),
      );
    });
  }

  testWidgets('gaveta: separador entre Artigos e Importar e os 6 navegam', (
    tester,
  ) async {
    await _tamanho(tester, 400);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final separador = find.descendant(
      of: find.byType(NavigationDrawer),
      matching: find.byType(Divider),
    );
    expect(separador, findsOneWidget);
    final y = tester.getCenter(separador).dy;
    expect(y, greaterThan(tester.getCenter(find.text(destinos[3].rotulo)).dy));
    expect(y, lessThan(tester.getCenter(find.text(destinos[4].rotulo)).dy));

    for (final d in destinos.reversed) {
      if (find.byType(NavigationDrawer).evaluate().isEmpty) {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.text(d.rotulo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pagina ${d.caminho}'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final gaveta = tester.widget<NavigationDrawer>(
        find.byType(NavigationDrawer),
      );
      expect(gaveta.selectedIndex, destinos.indexOf(d), reason: d.caminho);
    }
  });

  testWidgets('gaveta: cabeçalho em gradiente cobre a margem de cima', (
    tester,
  ) async {
    await _tamanho(tester, 400);
    tester.view.padding = const FakeViewPadding(top: 24);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final cabecalho = find.descendant(
      of: find.byType(NavigationDrawer),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient,
      ),
    );
    expect(cabecalho, findsOneWidget);
    expect(tester.getTopLeft(cabecalho).dy, 0);
    expect(
      tester.getTopLeft(find.text('Cabaz Mensal')).dy,
      greaterThanOrEqualTo(24),
    );
  });

  testWidgets('barra inferior com contorno de cima outlineVariant', (
    tester,
  ) async {
    await _tamanho(tester, 400);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();

    final caixa = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final borda = (caixa.decoration as BoxDecoration).border! as Border;
    final esquema = construirTema(
      Brightness.light,
      fontesGoogle: false,
    ).colorScheme;
    expect(borda.top, BorderSide(color: esquema.outlineVariant));
  });

  group('Pagina com filtros no cabeçalho', () {
    Future<void> abrir(
      WidgetTester t,
      Size tamanho, {
      List<Widget> filtros = const [],
      Widget? pesquisa,
      double letra = 1,
      double margemCima = 0,
    }) async {
      t.view.physicalSize = tamanho;
      t.view.devicePixelRatio = 1;
      t.view.padding = FakeViewPadding(top: margemCima);
      t.platformDispatcher.textScaleFactorTestValue = letra;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(
        MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: Pagina(
            titulo: 'Histórico',
            filtros: filtros,
            pesquisa: pesquisa,
            corpo: ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 48, child: Text('linha $i')),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    final pilulas = [
      FiltroPilula<int>(
        rotulo: 'Período',
        icone: Icons.calendar_month,
        valor: 1,
        opcoes: const {1: 'Este mês', 2: 'Este ano'},
        aoMudar: (_) {},
      ),
      FiltroPilula<String?>(
        rotulo: 'Loja',
        icone: Icons.storefront,
        valor: null,
        opcoes: const {null: 'Todas as lojas', 'l1': 'Supermercado A'},
        aoMudar: (_) {},
      ),
    ];

    testWidgets('pílulas e pesquisa ficam dentro do cabeçalho', (t) async {
      await abrir(
        t,
        const Size(400, 800),
        filtros: pilulas,
        pesquisa: CampoPesquisa(dica: 'Pesquisar', aoEscrever: (_) {}),
      );
      for (final f in [
        find.text('Este mês'),
        find.text('Todas as lojas'),
        find.byType(CampoPesquisa),
      ]) {
        expect(
          find.descendant(of: find.byType(CabecalhoPagina), matching: f),
          findsOneWidget,
        );
      }
    });

    testWidgets('sem filtros o cabeçalho só tem o título', (t) async {
      await abrir(t, const Size(400, 800));
      expect(
        find.descendant(
          of: find.byType(CabecalhoPagina),
          matching: find.byType(Wrap),
        ),
        findsNothing,
      );
      expect(find.byType(CampoPesquisa), findsNothing);
    });

    testWidgets('o gradiente cobre a margem de cima do sistema', (t) async {
      await abrir(t, const Size(400, 800), margemCima: 24);
      expect(t.getTopLeft(find.byType(CabecalhoPagina)).dy, 0);
      expect(t.getTopLeft(find.text('Histórico')).dy, greaterThanOrEqualTo(24));
    });

    testWidgets('com altura: cabeçalho fixo enquanto a lista rola', (t) async {
      await abrir(t, const Size(400, 800), filtros: pilulas);
      await t.drag(find.text('linha 3'), const Offset(0, -400));
      await t.pumpAndSettle();
      expect(find.text('Este mês'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('com pouca altura (deitado, teclado aberto): sem transbordos '
        'e o cabeçalho rola com a lista', (t) async {
      await abrir(t, const Size(475, 300), filtros: pilulas);
      expect(t.takeException(), isNull);
      await t.drag(find.text('linha 0'), const Offset(0, -600));
      await t.pumpAndSettle();
      expect(find.text('Este mês'), findsNothing);
      expect(find.textContaining('linha'), findsWidgets);
    });

    testWidgets('a pesquisa não perde o foco quando a altura baixa', (t) async {
      await abrir(
        t,
        const Size(400, 800),
        pesquisa: CampoPesquisa(dica: 'Pesquisar', aoEscrever: (_) {}),
      );
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'leite');
      await t.pump();
      // O teclado tira altura: o cabeçalho passa a rolar.
      t.view.physicalSize = const Size(400, 450);
      await t.pumpAndSettle();
      expect(find.byType(NestedScrollView), findsOneWidget);
      final campo = t.widget<EditableText>(find.byType(EditableText));
      expect(campo.focusNode.hasFocus, isTrue);
      expect(campo.controller.text, 'leite');
    });

    for (final largura in [360.0, 820.0]) {
      testWidgets('letra ×2 a $largura px: sem transbordos', (t) async {
        await abrir(
          t,
          Size(largura, 800),
          filtros: pilulas,
          pesquisa: CampoPesquisa(dica: 'Pesquisar', aoEscrever: (_) {}),
          letra: 2,
        );
        expect(t.takeException(), isNull);
      });
    }
  });
}
