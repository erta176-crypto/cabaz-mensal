import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/artigos/ver_artigo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _leite = Artigo(
  id: 'a1',
  nome: 'Leite',
  categoriaId: null,
  unidade: Unidade.un,
);
const _lojas = [
  Loja(id: 'l1', slug: 'continente', nome: 'Continente', cor: '#eb6834'),
  Loja(id: 'l2', slug: 'lidl', nome: 'Lidl'),
];

RegistoPreco _registo(String id, String loja, DateTime data, int cent) =>
    RegistoPreco(
      id: id,
      artigoId: 'a1',
      lojaId: loja,
      data: data,
      precoCent: cent,
      origem: OrigemPreco.manual,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  Future<void> abrir(WidgetTester t, List<RegistoPreco> registos) async {
    t.view.physicalSize = const Size(600, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          lojasProvider.overrideWith((_) => Stream.value(_lojas)),
          categoriasProvider.overrideWith((_) => Stream.value(const [])),
          precosAtuaisProvider.overrideWith((_) => Stream.value(const [])),
          registosPrecoProvider.overrideWith((_, _) => Stream.value(registos)),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const DialogoVerArtigo(artigo: _leite),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  testWidgets('com 3 registos mostra a evolução com um LineChart', (t) async {
    await abrir(t, [
      _registo('r1', 'l1', DateTime(2026, 9, 1), 99),
      _registo('r2', 'l2', DateTime(2026, 9, 10), 95),
      _registo('r3', 'l1', DateTime(2026, 10, 1), 105),
    ]);
    expect(find.text('Evolução do preço'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('com 1 registo mostra a mensagem', (t) async {
    await abrir(t, [_registo('r1', 'l1', DateTime(2026, 9, 1), 99)]);
    expect(find.text('Evolução do preço'), findsOneWidget);
    expect(
      find.text('Ainda não há registos suficientes para o gráfico.'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('"Fechar" fecha o diálogo', (t) async {
    await abrir(t, const []);
    await t.tap(find.text('Fechar'));
    await t.pumpAndSettle();
    expect(find.byType(DialogoVerArtigo), findsNothing);
  });

  testWidgets('"Editar" abre o diálogo de edição', (t) async {
    await abrir(t, const []);
    await t.tap(find.text('Editar'));
    await t.pumpAndSettle();
    expect(find.text('Editar artigo'), findsOneWidget);
  });
}
