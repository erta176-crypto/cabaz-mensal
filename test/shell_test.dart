import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(String inicial, {Widget? acaoMenu}) {
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
    theme: construirTema(Brightness.light, fontesGoogle: false),
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

  testWidgets('o corte é exatamente nos 800 px', (tester) async {
    await _tamanho(tester, 799);
    await tester.pumpWidget(_app('/lista'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await _tamanho(tester, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });
}
