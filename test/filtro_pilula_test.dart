import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/shell/filtro_pilula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String?>> abrir(WidgetTester t, String? valor) async {
    final escolhas = <String?>[];
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light, fontesGoogle: false),
        home: Scaffold(
          body: Center(
            child: FiltroPilula<String?>(
              rotulo: 'Loja',
              icone: Icons.storefront,
              valor: valor,
              opcoes: const {null: 'Todas as lojas', 'l1': 'Supermercado A'},
              aoMudar: escolhas.add,
            ),
          ),
        ),
      ),
    );
    return escolhas;
  }

  testWidgets('mostra o valor atual e tem área de toque ≥ 48', (t) async {
    await abrir(t, 'l1');
    expect(find.text('Supermercado A'), findsOneWidget);
    expect(
      t.getSize(find.byType(FiltroPilula<String?>)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('escolher no menu chama aoMudar, também com o valor null', (
    t,
  ) async {
    final escolhas = await abrir(t, 'l1');
    await t.tap(find.text('Supermercado A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Todas as lojas').last);
    await t.pumpAndSettle();
    expect(escolhas, [null]);

    await t.tap(find.text('Supermercado A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Supermercado A').last);
    await t.pumpAndSettle();
    expect(escolhas, [null, 'l1']);
  });

  testWidgets('leitor de ecrã: "Rótulo: valor" como botão', (t) async {
    final semantica = t.ensureSemantics();
    await abrir(t, null);
    expect(
      t.getSemantics(find.byType(FiltroPilula<String?>)),
      matchesSemantics(
        label: 'Loja: Todas as lojas',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantica.dispose();
  });
}
