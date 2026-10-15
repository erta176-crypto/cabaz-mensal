import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(String inicial) {
  final router = GoRouter(
    initialLocation: inicial,
    routes: [
      ShellRoute(
        builder: (_, estado, filho) =>
            AppShell(localizacao: estado.matchedLocation, child: filho),
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
