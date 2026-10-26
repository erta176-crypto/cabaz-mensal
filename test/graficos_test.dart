import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/estatisticas/barras_horizontais.dart';
import 'package:cabaz_mensal/features/estatisticas/cores.dart';
import 'package:cabaz_mensal/features/estatisticas/grafico_meses.dart';
import 'package:cabaz_mensal/features/estatisticas/grafico_preco.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _mostrar(WidgetTester t, Widget w) async {
  await t.pumpWidget(
    MaterialApp(
      theme: construirTema(Brightness.light, fontesGoogle: false),
      home: Scaffold(body: SingleChildScrollView(child: w)),
    ),
  );
  await t.pumpAndSettle();
}

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
      origem: OrigemPreco.talao,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  group('corDaLoja', () {
    final esquema = construirTema(
      Brightness.light,
      fontesGoogle: false,
    ).colorScheme;

    test('#rrggbb vira a cor da loja', () {
      expect(corDaLoja(_lojas[0], esquema), const Color(0xFFEB6834));
    });

    test('sem # ou null → primary', () {
      expect(
        corDaLoja(
          const Loja(id: 'x', slug: 'x', nome: 'X', cor: 'eb6834'),
          esquema,
        ),
        esquema.primary,
      );
      expect(corDaLoja(_lojas[1], esquema), esquema.primary);
    });
  });

  group('BarrasHorizontais', () {
    testWidgets('mostra rótulos e valores formatados', (t) async {
      await _mostrar(
        t,
        const BarrasHorizontais(
          itens: [
            (rotulo: 'Laticínios', cent: 12345, cor: Colors.red),
            (rotulo: 'Fruta', cent: 500, cor: Colors.blue),
          ],
        ),
      );
      expect(find.text('Laticínios'), findsOneWidget);
      expect(find.text('Fruta'), findsOneWidget);
      expect(find.text(formatarCent(12345)), findsOneWidget);
      expect(find.text(formatarCent(500)), findsOneWidget);
      expect(
        find.bySemanticsLabel('Laticínios: ${formatarCent(12345)}'),
        findsOneWidget,
      );
    });

    testWidgets('lista vazia mostra a mensagem', (t) async {
      await _mostrar(t, const BarrasHorizontais(itens: []));
      expect(find.text('Sem dados no período.'), findsOneWidget);
    });
  });

  testWidgets('GraficoMeses: BarChart e Semantics com os 3 valores', (t) async {
    await _mostrar(
      t,
      GraficoMeses(
        meses: [
          TotalMes(DateTime(2026, 8), 1000, 1),
          TotalMes(DateTime(2026, 9), 0, 0),
          TotalMes(DateTime(2026, 10), 12345, 3),
        ],
      ),
    );
    expect(find.byType(BarChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Gasto por mês. agosto 2026: ${formatarCent(1000)}; '
        'setembro 2026: ${formatarCent(0)}; '
        'outubro 2026: ${formatarCent(12345)}',
      ),
      findsOneWidget,
    );
  });

  group('GraficoPreco', () {
    testWidgets('com 1 registo mostra a mensagem', (t) async {
      await _mostrar(
        t,
        GraficoPreco(
          registos: [_registo('r1', 'l1', DateTime(2026, 10, 1), 199)],
          lojas: _lojas,
        ),
      );
      expect(
        find.text('Ainda não há registos suficientes para o gráfico.'),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('com 3 registos em 2 lojas: LineChart e legenda', (t) async {
      await _mostrar(
        t,
        GraficoPreco(
          registos: [
            _registo('r1', 'l1', DateTime(2026, 9, 1), 199),
            _registo('r2', 'l2', DateTime(2026, 9, 15), 189),
            _registo('r3', 'l1', DateTime(2026, 10, 1), 209),
          ],
          lojas: _lojas,
        ),
      );
      expect(find.byType(LineChart), findsOneWidget);
      final dados = t.widget<LineChart>(find.byType(LineChart)).data;
      // Sem rótulos soltos no mínimo e no máximo do eixo.
      expect(dados.titlesData.leftTitles.sideTitles.minIncluded, isFalse);
      expect(dados.titlesData.leftTitles.sideTitles.maxIncluded, isFalse);
      // Margem para os pontos das pontas não ficarem cortados.
      expect(dados.minX, lessThan(0));
      expect(dados.maxX, greaterThan(30)); // último registo: 30 dias
      expect(find.text('Continente'), findsOneWidget);
      expect(find.text('Lidl'), findsOneWidget);
    });
  });
}
