import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/artigos/artigos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fruta = Categoria(id: 'cat-fruta', nome: 'Fruta', ordem: 1);
const _lat = Categoria(id: 'cat-lat', nome: 'Laticínios', ordem: 2);
const _limpeza = Categoria(id: 'cat-limpeza', nome: 'Limpeza', ordem: 3);

/// Recusa os nomes como o repositório real (testado em
/// test/sync/categorias_sync_test.dart) e regista o que é chamado.
class _Categorias implements CategoriasRepository {
  final chamadas = <String>[];

  @override
  Future<void> atualizar(Categoria categoria) async {
    switch (categoria.nome.toLowerCase()) {
      case 'laticinios' || 'laticínios':
        throw ErroNomeRepetido(_lat, apagada: false);
      case 'limpeza':
        throw ErroNomeRepetido(_limpeza, apagada: true);
    }
    chamadas.add('atualizar ${categoria.nome}');
  }

  @override
  Future<void> juntar(String origemId, String destinoId) async =>
      chamadas.add('juntar $origemId $destinoId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Categorias repo;

  Future<void> abrir(WidgetTester tester) async {
    repo = _Categorias();
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasRepositoryProvider.overrideWithValue(repo),
          categoriasProvider.overrideWith(
            (_) => Stream.value(const [_fruta, _lat]),
          ),
          artigosProvider.overrideWith(
            (_) => Stream.value(const [
              Artigo(
                id: 'art-banana',
                nome: 'Banana',
                categoriaId: 'cat-fruta',
                unidade: Unidade.un,
              ),
            ]),
          ),
          lojasProvider.overrideWith((_) => Stream.value(const [])),
          precosAtuaisProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: const ArtigosPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Mostrar → Categorias.
    await tester.tap(find.text('Artigos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorias').last);
    await tester.pumpAndSettle();
  }

  Future<void> renomear(WidgetTester tester, String nome) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Fruta'),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), nome);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets('nome de outra ativa: oferece "Juntar" e junta quando o aviso '
      'fecha', (tester) async {
    await abrir(tester);
    await renomear(tester, 'laticinios');

    expect(find.text('Já existe a categoria "Laticínios"'), findsOneWidget);
    expect(
      find.text(
        'O artigo de "Fruta" passa para "Laticínios" e "Fruta" é eliminada.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Juntar a "Laticínios"'));
    await tester.pumpAndSettle();
    expect(find.text('"Fruta" junta-se a "Laticínios".'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Fruta'), findsNothing);
    expect(repo.chamadas, isEmpty, reason: 'só depois do aviso');

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(repo.chamadas, ['juntar cat-fruta cat-lat']);
  });

  testWidgets('"Anular" não junta e a categoria volta', (tester) async {
    await abrir(tester);
    await renomear(tester, 'Laticínios');
    await tester.tap(find.text('Juntar a "Laticínios"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Fruta'), findsOneWidget);
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('nome de uma eliminada: oferece "Recuperar e juntar"', (
    tester,
  ) async {
    await abrir(tester);
    await renomear(tester, 'LIMPEZA');

    expect(find.text('A categoria "Limpeza" foi eliminada'), findsOneWidget);
    await tester.tap(find.text('Recuperar "Limpeza" e juntar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(repo.chamadas, ['juntar cat-fruta cat-limpeza']);
  });

  testWidgets('"Cancelar" não grava nem junta', (tester) async {
    await abrir(tester);
    await renomear(tester, 'Laticínios');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Fruta'), findsOneWidget);
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('nome livre: grava sem perguntar', (tester) async {
    await abrir(tester);
    await renomear(tester, 'Fruta fresca');
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.chamadas, ['atualizar Fruta fresca']);
  });
}
