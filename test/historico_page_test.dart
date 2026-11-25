import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/historico/detalhe_compra.dart';
import 'package:cabaz_mensal/features/historico/historico_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _lojas = [
  Loja(id: 'l1', slug: 'continente', nome: 'Continente', cor: '#eb6834'),
  Loja(id: 'l2', slug: 'lidl', nome: 'Lidl'),
];
const _artigos = [
  Artigo(id: 'm1', nome: 'Maçã', categoriaId: null, unidade: Unidade.kg),
];

CompraResumo _compra(String id, String loja, DateTime data, int cent) =>
    CompraResumo(
      id: id,
      lojaId: loja,
      data: data,
      totalCent: cent,
      poupancaCent: 0,
      origem: 'talao',
      rever: false,
      nLinhas: 3,
    );

final _compras = [
  _compra('c1', 'l1', DateTime(2026, 10, 20), 4000),
  _compra('c2', 'l2', DateTime(2026, 10, 5), 1500),
  _compra('c3', 'l1', DateTime(2026, 9, 28), 2000),
];

class _EstatisticasFalsas implements EstatisticasRepository {
  _EstatisticasFalsas(this.resposta);

  Future<List<CompraResumo>> Function() resposta;
  final pedidos =
      <({FiltroCompras filtro, List<String>? ids, String? texto})>[];

  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) =>
      throw UnimplementedError();

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) {
    pedidos.add((filtro: filtro, ids: artigoIds, texto: texto));
    return resposta();
  }

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async => const [];

  @override
  Future<DetalhePainel> artigosDoPainel(
    FiltroCompras filtro, {
    String? lojaId,
    List<String>? categoriaIds,
    bool semCategoria = false,
    DateTime? hoje,
  }) => throw UnimplementedError();
}

/// Só o que o Histórico usa para eliminar e repor talões (Fase 15).
class _Dados implements DadosRepository {
  final eliminadas = <String>{};
  final pedidos = <String>[];
  bool semRede = false;

  @override
  Future<void> eliminarCompra(String id) async {
    if (semRede) {
      throw const ErroDados('Sem rede: liga-te para eliminar o talão.');
    }
    pedidos.add('eliminar $id');
    eliminadas.add(id);
  }

  @override
  Future<void> reporCompra(String id) async {
    pedidos.add('repor $id');
    eliminadas.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  Future<void> abrir(
    WidgetTester t,
    _EstatisticasFalsas repo, {
    double largura = 400,
    double altura = 1600,
    double menu = 0,
    _Dados? dados,
  }) async {
    t.view.physicalSize = Size(largura, altura);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          estatisticasRepositoryProvider.overrideWithValue(repo),
          lojasProvider.overrideWith((_) => Stream.value(_lojas)),
          artigosProvider.overrideWith((_) => Stream.value(_artigos)),
          aliasesProvider.overrideWith((_) => Stream.value(const {})),
          if (dados != null) dadosRepositoryProvider.overrideWithValue(dados),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          // [menu] simula o menu fixo do ecrã largo, ao lado da página.
          home: Row(
            children: [
              SizedBox(width: menu),
              const Expanded(child: HistoricoPage()),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('agrupa por mês com o cabeçalho certo', (t) async {
    final repo = _EstatisticasFalsas(() async => _compras);
    await abrir(t, repo);
    expect(repo.pedidos.single.filtro, (
      periodo: Periodo.ultimos12Meses,
      lojaId: null,
    ));
    expect(
      find.text('outubro de 2026 · 2 compras · ${formatarCent(5500)}'),
      findsOneWidget,
    );
    expect(
      find.text('setembro de 2026 · 1 compra · ${formatarCent(2000)}'),
      findsOneWidget,
    );
    expect(find.text('Lidl'), findsWidgets);
  });

  testWidgets('escrever "maca" e esperar 400 ms envia o id da Maçã', (t) async {
    final repo = _EstatisticasFalsas(() async => _compras);
    await abrir(t, repo);
    await t.enterText(find.byType(TextField), 'maca');
    await t.pump(const Duration(milliseconds: 300));
    expect(repo.pedidos, hasLength(1));
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    expect(repo.pedidos.last.ids, ['m1']);
    expect(repo.pedidos.last.texto, 'maca');
  });

  testWidgets('sem resultados com pesquisa', (t) async {
    final repo = _EstatisticasFalsas(() async => const []);
    await abrir(t, repo);
    expect(find.text('Não há compras neste período.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'xyz');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('Nenhuma compra encontrada.'), findsOneWidget);
  });

  testWidgets('a 400 px tocar numa compra abre o DetalheCompraPage', (t) async {
    await abrir(t, _EstatisticasFalsas(() async => _compras));
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsOneWidget);
  });

  testWidgets('a 1000 px o detalhe aparece ao lado', (t) async {
    await abrir(t, _EstatisticasFalsas(() async => _compras), largura: 1000);
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsNothing);
    expect(find.byType(DetalheCompra), findsOneWidget);
    expect(find.byType(HistoricoPage), findsOneWidget);
  });

  testWidgets('ecrã largo mas pouco espaço ao lado do menu: uma coluna', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => _compras),
      largura: 900,
      altura: 600,
      menu: 380,
    );
    expect(t.takeException(), isNull);
    await t.tap(find.text(formatarCent(1500)));
    await t.pumpAndSettle();
    expect(find.byType(DetalheCompraPage), findsOneWidget);
  });

  testWidgets('deitado com o teclado aberto (475×200): sem transbordos', (
    t,
  ) async {
    await abrir(
      t,
      _EstatisticasFalsas(() async => _compras),
      largura: 475,
      altura: 200,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('erro sem rede mostra a mensagem', (t) async {
    await abrir(
      t,
      _EstatisticasFalsas(
        () async =>
            throw const ErroDados('Sem rede: o histórico precisa do servidor.'),
      ),
    );
    expect(
      find.text('Sem rede: o histórico precisa do servidor.'),
      findsOneWidget,
    );
    expect(find.text('Tentar outra vez'), findsOneWidget);
  });

  group('eliminar talão (Fase 15)', () {
    late _Dados dados;
    late _EstatisticasFalsas repo;

    Future<void> abrirComDados(WidgetTester t, {double largura = 400}) {
      dados = _Dados();
      repo = _EstatisticasFalsas(
        () async => [
          for (final c in _compras)
            if (!dados.eliminadas.contains(c.id)) c,
        ],
      );
      return abrir(t, repo, dados: dados, largura: largura);
    }

    Future<void> pedirEliminar(WidgetTester t) async {
      // O primeiro talão da lista é o c1 (Continente, 20/10, 40 €).
      await t.tap(find.byTooltip('Ações do talão').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar talão'));
      await t.pumpAndSettle();
    }

    Finder noDialogo(String texto) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.textContaining(texto),
    );

    testWidgets('o diálogo mostra loja, data e total; "Cancelar" não elimina', (
      t,
    ) async {
      await abrirComDados(t);
      await pedirEliminar(t);
      expect(noDialogo('Continente'), findsOneWidget);
      expect(noDialogo(formatarData(DateTime(2026, 10, 20))), findsOneWidget);
      expect(noDialogo(formatarCent(4000)), findsOneWidget);

      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(dados.pedidos, isEmpty);
      expect(find.text(formatarCent(4000)), findsOneWidget);
    });

    testWidgets('eliminar tira o talão da lista e mostra "Anular"', (t) async {
      await abrirComDados(t);
      final pedidosAntes = repo.pedidos.length;
      await pedirEliminar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await t.pumpAndSettle();

      expect(dados.pedidos, ['eliminar c1']);
      expect(repo.pedidos.length, greaterThan(pedidosAntes));
      expect(find.text(formatarCent(4000)), findsNothing);
      expect(find.text('Talão eliminado.'), findsOneWidget);
      expect(find.text('Anular'), findsOneWidget);
    });

    testWidgets('"Anular" repõe o talão', (t) async {
      await abrirComDados(t);
      await pedirEliminar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Anular'));
      await t.pumpAndSettle();

      expect(dados.pedidos, ['eliminar c1', 'repor c1']);
      expect(find.text(formatarCent(4000)), findsOneWidget);
    });

    testWidgets('sem rede: mostra a mensagem e o talão fica', (t) async {
      await abrirComDados(t);
      dados.semRede = true;
      await pedirEliminar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await t.pumpAndSettle();

      expect(
        find.text('Sem rede: liga-te para eliminar o talão.'),
        findsOneWidget,
      );
      expect(find.text(formatarCent(4000)), findsOneWidget);
      expect(find.text('Talão eliminado.'), findsNothing);
    });

    testWidgets('ecrã largo: eliminar o talão aberto limpa o detalhe', (
      t,
    ) async {
      await abrirComDados(t, largura: 1000);
      await t.tap(find.text(formatarCent(4000)));
      await t.pumpAndSettle();
      expect(find.byType(DetalheCompra), findsOneWidget);

      await pedirEliminar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await t.pumpAndSettle();
      expect(find.byType(DetalheCompra), findsNothing);
      expect(find.text('Escolhe uma compra.'), findsOneWidget);
    });

    testWidgets('no detalhe (telemóvel): eliminar fecha o detalhe e o aviso '
        'aparece no Histórico', (t) async {
      await abrirComDados(t);
      await t.tap(find.text(formatarCent(4000)));
      await t.pumpAndSettle();
      expect(find.byType(DetalheCompraPage), findsOneWidget);

      await t.tap(find.byTooltip('Ações do talão'));
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar talão'));
      await t.pumpAndSettle();
      expect(noDialogo('Continente'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await t.pumpAndSettle();

      expect(find.byType(DetalheCompraPage), findsNothing);
      expect(dados.pedidos, ['eliminar c1']);
      expect(find.text('Talão eliminado.'), findsOneWidget);
      expect(find.text(formatarCent(4000)), findsNothing);
    });
  });
}
