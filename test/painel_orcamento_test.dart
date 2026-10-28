import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/domain/orcamento.dart';
import 'package:cabaz_mensal/features/painel/painel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

final _agora = DateTime.now();
final _mes = DateTime(_agora.year, _agora.month);
final _anterior = DateTime(_agora.year, _agora.month - 1);

const _categorias = [
  Categoria(id: 'c1', nome: 'Laticínios', ordem: 1),
  Categoria(id: 'c2', nome: 'Fruta', ordem: 2),
];

class _Estatisticas implements EstatisticasRepository {
  final filtros = <FiltroCompras>[];

  @override
  Future<ResultadoPainel> painel(FiltroCompras f, {DateTime? hoje}) async {
    filtros.add(f);
    return ResultadoPainel(
      DadosPainel(
        totalCent: 42000,
        nCompras: 5,
        poupancaCent: 0,
        porMes: const [],
        porLoja: const [],
        porCategoria: const [TotalCategoria('c1', 11000)],
        artigos: const [],
      ),
    );
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

class _Orcamentos implements OrcamentosRepository {
  _Orcamentos(this.lista);
  final List<Orcamento> lista;
  final definidos = <(DateTime, String?, int?)>[];
  final copias = <(DateTime, DateTime)>[];

  @override
  Stream<List<Orcamento>> observar() => Stream.value(lista);

  @override
  Future<void> definir(DateTime mes, String? c, int? v) async =>
      definidos.add((mes, c, v));

  @override
  Future<void> copiar(DateTime de, DateTime para) async =>
      copias.add((de, para));
}

Orcamento _orc(DateTime mes, String? c, int v) => Orcamento(
  id: idOrcamento('u1', mes, c),
  mes: mes,
  categoriaId: c,
  valorCent: v,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  Future<_Orcamentos> abrir(WidgetTester t, List<Orcamento> lista) async {
    t.view.physicalSize = const Size(500, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final orc = _Orcamentos(lista);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          estatisticasRepositoryProvider.overrideWithValue(_Estatisticas()),
          orcamentosRepositoryProvider.overrideWithValue(orc),
          lojasProvider.overrideWith((_) => Stream.value(const [])),
          categoriasProvider.overrideWith((_) => Stream.value(_categorias)),
          artigosProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: const PainelPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    return orc;
  }

  String mesAnterior() => DateFormat('MMMM', 'pt_PT').format(_anterior);

  testWidgets('sem orçamento: Definir e Copiar do mês anterior', (t) async {
    final orc = await abrir(t, [_orc(_anterior, null, 50000)]);
    expect(find.text('Orçamento'), findsOneWidget);
    expect(find.text('Definir orçamento'), findsOneWidget);
    await t.tap(find.text('Copiar de ${mesAnterior()}'));
    await t.pumpAndSettle();
    expect(orc.copias.single, (_anterior, _mes));
  });

  testWidgets('sem orçamento em nenhum mês: sem botão de copiar', (t) async {
    await abrir(t, const []);
    expect(find.text('Definir orçamento'), findsOneWidget);
    expect(find.textContaining('Copiar de'), findsNothing);
  });

  testWidgets('com orçamento: faltam, passou e nível em texto', (t) async {
    await abrir(t, [
      _orc(_mes, null, 50000), // gasto 420 de 500: quase
      _orc(_mes, 'c1', 10000), // gasto 110 de 100: passou
    ]);
    expect(
      find.text(
        '${formatarCent(42000)} de ${formatarCent(50000)} · '
        'faltam ${formatarCent(8000)} · quase no limite',
      ),
      findsOneWidget,
    );
    expect(find.text('Laticínios'), findsWidgets);
    expect(
      find.text(
        '${formatarCent(11000)} de ${formatarCent(10000)} · '
        'passou ${formatarCent(1000)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('percentagens e cor da barra por nível; sem "Ultrapassado"', (
    t,
  ) async {
    await abrir(t, [
      _orc(_mes, null, 50000), // 420 de 500: quase, 84 %
      _orc(_mes, 'c1', 10000), // 110 de 100: passou, 110 %
      _orc(_mes, 'c2', 5000), // 0 de 50: ok, 0 %
    ]);
    expect(find.text('84 %'), findsOneWidget);
    expect(find.text('110 %'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('Ultrapassado'), findsNothing);

    final tema = construirTema(Brightness.light, fontesGoogle: false);
    final barras = t
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(barras.map((b) => b.color), [
      tema.colorScheme.tertiary,
      tema.colorScheme.error,
      CoresCabaz.claro.ok,
    ]);
    for (final b in barras) {
      expect(b.backgroundColor, CoresCabaz.claro.pista);
      expect(b.minHeight, 6);
    }
  });

  testWidgets('"Ultrapassado" quando o total do mês passou', (t) async {
    await abrir(t, [_orc(_mes, null, 40000)]); // 420 de 400
    expect(find.text('105 %'), findsOneWidget);
    expect(find.text('Ultrapassado'), findsOneWidget);
  });

  testWidgets('cartões: valor da Poupança na cor ok', (t) async {
    await abrir(t, const []);
    final poupanca = t.widget<Text>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Poupança'),
          matching: find.byType(Card),
        ),
        matching: find.text(formatarCent(0)),
      ),
    );
    expect(poupanca.style?.color, CoresCabaz.claro.ok);
    expect(poupanca.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('com outro período o cartão não aparece', (t) async {
    await abrir(t, [_orc(_mes, null, 50000)]);
    await t.tap(find.text('Este mês'));
    await t.pumpAndSettle();
    await t.tap(find.text('Este ano').last);
    await t.pumpAndSettle();
    expect(find.text('Orçamento'), findsNothing);
  });

  testWidgets('diálogo grava total e categoria e ignora vazios', (t) async {
    final orc = await abrir(t, const []);
    await t.tap(find.text('Definir orçamento'));
    await t.pumpAndSettle();
    expect(find.text('Editar orçamento'), findsOneWidget);
    // O rótulo do primeiro campo flutua acima da caixa: não pode ficar
    // cortado pelo topo da zona com scroll.
    expect(
      t.getRect(find.text('Total do mês (€)')).top,
      greaterThanOrEqualTo(
        t.getRect(find.byType(SingleChildScrollView).last).top,
      ),
    );

    await t.enterText(
      find.widgetWithText(TextField, 'Total do mês (€)'),
      '500',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Laticínios (€)'),
      '100,50',
    );
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();

    expect(
      orc.definidos,
      unorderedEquals([(_mes, null, 50000), (_mes, 'c1', 10050)]),
    );
  });

  testWidgets('diálogo: apagar um valor existente envia null', (t) async {
    final orc = await abrir(t, [
      _orc(_mes, null, 50000),
      _orc(_mes, 'c1', 1000),
    ]);
    await t.tap(find.byTooltip('Ações do orçamento'));
    await t.pumpAndSettle();
    await t.tap(find.text('Editar orçamento'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Laticínios (€)'), '');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(orc.definidos, [(_mes, 'c1', null)]);
  });

  testWidgets('valor inválido mostra erro e não grava', (t) async {
    final orc = await abrir(t, const []);
    await t.tap(find.text('Definir orçamento'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Total do mês (€)'),
      'abc',
    );
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('Valor inválido'), findsOneWidget);
    expect(orc.definidos, isEmpty);
  });
}
