import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/historico/detalhe_compra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _lojas = [Loja(id: 'l1', slug: 'continente', nome: 'Continente')];
const _artigos = [
  Artigo(id: 'a1', nome: 'Leite', categoriaId: null, unidade: Unidade.un),
];

final _compra = CompraResumo(
  id: 'c1',
  lojaId: 'l1',
  data: DateTime(2026, 10, 20),
  local: 'Alvalade',
  totalCent: 412,
  poupancaCent: 50,
  origem: 'talao',
  rever: true,
  nLinhas: 3,
);

const _linhas = [
  LinhaCompra(
    id: 'x1',
    compraId: 'c1',
    artigoId: 'a1',
    textoOriginal: 'LEITE UHT MG',
    quantidade: 2,
    pesoG: null,
    precoUnitCent: 80,
    brutoCent: 160,
    descontoCent: 0,
    pagoCent: 160,
  ),
  LinhaCompra(
    id: 'x2',
    compraId: 'c1',
    artigoId: null,
    textoOriginal: 'BANANA',
    quantidade: null,
    pesoG: 794,
    precoUnitCent: 129,
    brutoCent: 102,
    descontoCent: 0,
    pagoCent: 102,
  ),
  LinhaCompra(
    id: 'x3',
    compraId: 'c1',
    artigoId: null,
    textoOriginal: 'CAFE',
    quantidade: 1,
    pesoG: null,
    precoUnitCent: 200,
    brutoCent: 200,
    descontoCent: 50,
    pagoCent: 150,
  ),
];

class _Estatisticas implements EstatisticasRepository {
  @override
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje}) =>
      throw UnimplementedError();

  @override
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  }) async => const [];

  @override
  Future<List<LinhaCompra>> linhas(String compraId) async => _linhas;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  testWidgets('cabeçalho, linhas, peso, desconto e soma', (t) async {
    t.view.physicalSize = const Size(500, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          estatisticasRepositoryProvider.overrideWithValue(_Estatisticas()),
          lojasProvider.overrideWith((_) => Stream.value(_lojas)),
          artigosProvider.overrideWith((_) => Stream.value(_artigos)),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: DetalheCompraPage(compra: _compra),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Talão'), findsOneWidget);
    expect(find.text('A soma das linhas não bate com o total'), findsOneWidget);
    // Nome do artigo e, por baixo, o texto do talão.
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('LEITE UHT MG'), findsOneWidget);
    // Sem artigo: o texto do talão é o título.
    expect(find.text('BANANA'), findsOneWidget);
    expect(find.text('0,794 kg · ${formatarCent(129)}/kg'), findsOneWidget);
    expect(find.text('2 un · ${formatarCent(80)}'), findsOneWidget);
    expect(find.text('-${formatarCent(50)}'), findsOneWidget);
    expect(
      find.text('Soma das linhas: ${formatarCent(160 + 102 + 150)}'),
      findsOneWidget,
    );
  });
}
