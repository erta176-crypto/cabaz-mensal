import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _abrir(WidgetTester t, Size tamanho) async {
  t.view.physicalSize = tamanho;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: construirTema(Brightness.light, fontesGoogle: false),
      home: Scaffold(
        body: FiltrosEConteudo(
          filtros: const SizedBox(
            height: 220, // três menus empilhados
            child: Center(child: Text('filtros')),
          ),
          conteudo: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 48, child: Text('linha $i')),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('com altura: filtros fixos enquanto a lista rola', (t) async {
    await _abrir(t, const Size(400, 800));
    await t.drag(find.text('linha 3'), const Offset(0, -400));
    await t.pumpAndSettle();
    expect(find.text('filtros'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('com pouca altura (teclado aberto): sem transbordos e os '
      'filtros rolam com a lista', (t) async {
    await _abrir(t, const Size(475, 150));
    expect(t.takeException(), isNull);
    await t.drag(find.text('filtros'), const Offset(0, -400));
    await t.pumpAndSettle();
    expect(find.text('filtros'), findsNothing);
    expect(find.textContaining('linha'), findsWidgets);
  });
}
