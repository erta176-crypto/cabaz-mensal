import 'dart:async';

import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/domain/compra.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/domain/orcamento.dart';
import 'package:cabaz_mensal/domain/preferencias.dart';
import 'package:cabaz_mensal/domain/texto.dart';
import 'package:cabaz_mensal/export/texto_lista.dart';
import 'package:cabaz_mensal/features/lista/lista_logica.dart';
import 'package:cabaz_mensal/features/lista/lista_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const lidl = Loja(id: 'lidl', slug: 'lidl', nome: 'Lidl');
const pingo = Loja(id: 'pd', slug: 'pingo-doce', nome: 'Pingo Doce');
const fruta = Categoria(id: 'fruta', nome: 'Fruta', ordem: 1);
const mercearia = Categoria(id: 'merc', nome: 'Mercearia', ordem: 2);
const banana = Artigo(
  id: 'banana',
  nome: 'Banana',
  categoriaId: 'fruta',
  unidade: Unidade.kg,
);
const maca = Artigo(
  id: 'maca',
  nome: 'Maçã Fuji',
  categoriaId: 'fruta',
  unidade: Unidade.kg,
);
const arroz = Artigo(
  id: 'arroz',
  nome: 'Arroz',
  categoriaId: 'merc',
  unidade: Unidade.un,
);
const leite = Artigo(
  id: 'leite',
  nome: 'Leite',
  categoriaId: null,
  unidade: Unidade.un,
);

final precos = [
  PrecoAtual(
    artigoId: 'banana',
    lojaId: 'lidl',
    precoCent: 119,
    data: DateTime(2026),
  ),
  PrecoAtual(
    artigoId: 'arroz',
    lojaId: 'lidl',
    precoCent: 89,
    data: DateTime(2026),
  ),
  PrecoAtual(
    artigoId: 'leite',
    lojaId: 'lidl',
    precoCent: 75,
    data: DateTime(2026),
  ),
  PrecoAtual(
    artigoId: 'leite',
    lojaId: 'pd',
    precoCent: 79,
    data: DateTime(2026),
  ),
];

List<ItemLista> itensBase() => const [
  ItemLista(
    id: '1',
    lojaId: 'lidl',
    artigoId: 'banana',
    qtdPadrao: 1.3,
    incluido: true,
  ),
  ItemLista(
    id: '2',
    lojaId: 'lidl',
    artigoId: 'arroz',
    qtdPadrao: 2,
    incluido: true,
    comprado: true,
  ),
  ItemLista(
    id: '3',
    lojaId: 'lidl',
    artigoId: 'leite',
    qtdPadrao: 6,
    incluido: true,
  ),
  ItemLista(
    id: '4',
    lojaId: 'lidl',
    artigoId: 'maca',
    qtdPadrao: 1,
    incluido: false,
  ),
  ItemLista(
    id: '5',
    lojaId: 'pd',
    artigoId: 'leite',
    qtdPadrao: 2,
    incluido: true,
  ),
];

ListaMontada montar({
  List<ItemLista>? itens,
  Preferencias preferencias = const Preferencias(lojaId: 'lidl'),
}) => montarLista(
  lojas: const [lidl, pingo],
  categorias: const [mercearia, fruta],
  artigos: const [banana, maca, arroz, leite],
  itens: itens ?? itensBase(),
  precos: precos,
  preferencias: preferencias,
);

void main() {
  group('montar a lista', () {
    test(
      'por categoria, pela ordem das categorias, "Sem categoria" no fim',
      () {
        final l = montar();
        expect(l.secoes, hasLength(1));
        expect(l.secoes.single.grupos.map((g) => g.titulo), [
          'Fruta',
          'Mercearia',
          'Sem categoria',
        ]);
        // A maçã não está incluída: não aparece no supermercado.
        expect(
          l.linhas.map((x) => x.artigo.nome),
          isNot(contains('Maçã Fuji')),
        );
      },
    );

    test('comprados no fim do grupo e contagem comprados/total', () {
      final itens = [
        ...itensBase(),
        const ItemLista(
          id: '6',
          lojaId: 'lidl',
          artigoId: 'maca',
          qtdPadrao: 1,
          incluido: true,
          comprado: true,
        ),
      ]..removeWhere((i) => i.id == '4');
      final fruta = montar(itens: itens).secoes.single.grupos.first;
      expect(fruta.linhas.map((x) => x.artigo.nome), ['Banana', 'Maçã Fuji']);
      expect(fruta.comprados, 1);
    });

    test('por artigo, A–Z, com os comprados no fim', () {
      final l = montar(
        preferencias: const Preferencias(
          lojaId: 'lidl',
          organizar: Organizar.porArtigo,
        ),
      );
      expect(l.linhas.map((x) => x.artigo.nome), ['Banana', 'Leite', 'Arroz']);
    });

    test('Planear mostra também os não incluídos', () {
      final l = montar(
        preferencias: const Preferencias(
          lojaId: 'lidl',
          modo: ModoLista.planear,
        ),
      );
      expect(l.linhas.map((x) => x.artigo.nome), contains('Maçã Fuji'));
    });

    test('Todas as lojas: uma secção por loja', () {
      final l = montar(preferencias: const Preferencias());
      expect(l.secoes.map((s) => s.loja.nome), ['Lidl', 'Pingo Doce']);
    });

    test('totais estimados em cêntimos', () {
      final l = montar();
      // Banana 1,3 kg × 1,19 €/kg = 1,547 → 155; arroz 2 × 0,89 = 178;
      // leite 6 × 0,75 = 450.
      expect(l.totalEstimadoCent, 155 + 178 + 450);
      expect(l.totalCarrinhoCent, 178);
      expect(l.nComprados, 1);
    });

    test('texto da lista: por categoria e sem os comprados', () {
      final t = textoLista(
        linhasParaTexto(montar(), const [fruta, mercearia]),
        loja: 'Lidl',
        data: DateTime(2026, 10, 18),
      );
      expect(t, startsWith('🛒 Lista de compras · Lidl · 18/10/2026'));
      expect(t, contains('🍎 Fruta\n• Banana — 1,3 kg'));
      expect(t, isNot(contains('Arroz')), reason: 'já comprado');
      expect(t, contains('🛍️ Sem categoria\n• Leite — 6 un'));
    });
  });

  group('Concluir compra', () {
    LinhaNova linha(String id, Unidade u, int preco, {int? qtd, int? pesoG}) =>
        LinhaNova(
          id: id,
          precoId: 'p$id',
          artigoId: id,
          nome: id,
          unidade: u,
          precoUnitCent: preco,
          quantidade: qtd,
          pesoG: pesoG,
        );

    test('total com quantidades e pesos, sem doubles', () {
      final c = CompraNova(
        id: 'c',
        lojaId: 'lidl',
        local: null,
        data: DateTime(2026, 10, 15),
        linhas: [
          linha('a', Unidade.un, 10, qtd: 1), // 0,10
          linha('b', Unidade.un, 20, qtd: 1), // 0,20
          linha('c', Unidade.kg, 119, pesoG: 1300), // 1,547 → 1,55
        ],
      );
      expect(c.totalCalculadoCent, 30 + 155);
      expect(c.rever, isFalse);
    });

    test('total do talão diferente: rever e diferença', () {
      final c = CompraNova(
        id: 'c',
        lojaId: 'lidl',
        local: 'Lidl',
        data: DateTime(2026, 10, 15),
        linhas: [linha('a', Unidade.un, 89, qtd: 2)],
        totalTalaoCent: 180,
      );
      expect(c.rever, isTrue);
      expect(c.diferencaCent, 2);
      expect(c.totalCent, 180);
      expect(c.toPayload()['compra']['rever'], isTrue);
    });

    test('o payload é sempre igual para a mesma compra (idempotente)', () {
      CompraNova nova() => CompraNova(
        id: 'c1',
        lojaId: 'lidl',
        local: null,
        data: DateTime(2026, 10, 15),
        linhas: [linha('a', Unidade.kg, 119, pesoG: 794)],
      );
      expect(nova().toPayload(), nova().toPayload());
      final p = nova().toPayload();
      expect(p['compra']['id'], 'c1');
      expect((p['linhas'] as List).single['peso_g'], 794);
      expect((p['precos'] as List).single['id'], 'pa');
    });
  });

  test('pesquisa sem acentos nem maiúsculas, e por alias', () {
    expect(correspondeA('maca', ['Maçã Fuji']), isTrue);
    expect(correspondeA('MAÇÃ fuji', ['maca fuji']), isTrue);
    expect(
      correspondeA('frango vc', ['Peito de frango', 'FRANGO PEITO VC']),
      isTrue,
    );
    expect(correspondeA('pera', ['Maçã Fuji']), isFalse);
  });

  group('ecrã Lista (widgets)', () {
    setUpAll(() => initializeDateFormatting('pt_PT'));

    late _ListaFalsa lista;
    late _PreferenciasFalsas prefs;

    setUp(() {
      lista = _ListaFalsa(itensBase());
      prefs = _PreferenciasFalsas(const Preferencias(lojaId: 'lidl'));
    });

    Future<void> abrir(
      WidgetTester tester, {
      List<Orcamento> orcamentos = const [],
      int gastoMesCent = 0,
      Size tamanho = const Size(500, 1400),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lojasProvider.overrideWith(
              (_) => Stream.value(const [lidl, pingo]),
            ),
            categoriasProvider.overrideWith(
              (_) => Stream.value(const [fruta, mercearia]),
            ),
            artigosProvider.overrideWith(
              (_) => Stream.value(const [banana, maca, arroz, leite]),
            ),
            precosAtuaisProvider.overrideWith((_) => Stream.value(precos)),
            listaRepositoryProvider.overrideWithValue(lista),
            preferenciasRepositoryProvider.overrideWithValue(prefs),
            estadoSyncProvider.overrideWith(
              (_) => Stream.value(const EstadoSync()),
            ),
            orcamentosProvider.overrideWith((_) => Stream.value(orcamentos)),
            painelProvider.overrideWith(
              (_, _) async => ResultadoPainel(
                DadosPainel(
                  totalCent: gastoMesCent,
                  nCompras: 1,
                  poupancaCent: 0,
                  porMes: const [],
                  porLoja: const [],
                  porCategoria: const [],
                  artigos: const [],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: construirTema(Brightness.light, fontesGoogle: false),
            home: const ListaPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tocar no cabeçalho fecha e abre o grupo', (tester) async {
      await abrir(tester);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget); // Mercearia (arroz comprado)

      await tester.tap(find.text('Fruta'));
      await tester.pumpAndSettle();
      expect(find.text('Banana'), findsNothing);
      expect(prefs.atual.gruposFechados, {'lidl|fruta'});

      await tester.tap(find.text('Fruta'));
      await tester.pumpAndSettle();
      expect(find.text('Banana'), findsOneWidget);
    });

    testWidgets('gestos por defeito: esquerda marca comprado', (tester) async {
      await abrir(tester);
      await tester.drag(find.text('Banana'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(lista.chamadas, ['comprado banana true']);
    });

    testWidgets('direita remove da lista, com Anular', (tester) async {
      await abrir(tester);
      await tester.drag(find.text('Leite'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(lista.chamadas, ['incluido leite false']);
      expect(find.text('Leite'), findsNothing);
      expect(find.text('Anular'), findsOneWidget);

      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();
      expect(lista.chamadas.last, 'repor leite');
      expect(find.text('Leite'), findsOneWidget);
    });

    testWidgets('os gestos seguem as Definições', (tester) async {
      prefs = _PreferenciasFalsas(
        const Preferencias(
          lojaId: 'lidl',
          direita: AcaoGesto.marcarComprado,
          esquerda: AcaoGesto.removerDaLista,
          tocar: AcaoGesto.nada,
        ),
      );
      await abrir(tester);
      await tester.drag(find.text('Banana'), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(lista.chamadas, ['comprado banana true']);

      await tester.tap(find.text('Leite'));
      await tester.pumpAndSettle();
      expect(lista.chamadas, hasLength(1), reason: 'tocar = Nada');

      await tester.drag(find.text('Leite'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(lista.chamadas.last, 'incluido leite false');
    });

    testWidgets('rodapé com os totais e Concluir compra', (tester) async {
      await abrir(tester);
      expect(find.text('Concluir compra'), findsOneWidget);
      expect(find.textContaining('7,83'), findsOneWidget); // estimado
      expect(find.textContaining('1,78'), findsWidgets); // carrinho
    });

    testWidgets(
      'Adicionar artigo e Concluir compra lado a lado, sem se taparem',
      (tester) async {
        await abrir(tester);
        final adicionar = tester.getRect(find.text('Adicionar artigo'));
        final concluir = tester.getRect(find.text('Concluir compra'));
        expect(adicionar.overlaps(concluir), isFalse);
        expect(adicionar.center.dy, closeTo(concluir.center.dy, 1));
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    for (final escala in [1.0, 1.3]) {
      testWidgets('telemóvel deitado (área de 475×360, letra ×$escala): '
          'sem transbordos', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await abrir(tester, tamanho: const Size(475, 360));
        expect(tester.takeException(), isNull);
      });
    }

    group('orçamento no rodapé', () {
      final agora = DateTime.now();
      final mes = DateTime(agora.year, agora.month);
      Orcamento total(int cent) =>
          Orcamento(id: 'o1', mes: mes, valorCent: cent);

      testWidgets('mostra quanto falta e quanto fica depois da lista', (
        tester,
      ) async {
        // Estimado da lista: 7,83 €.
        await abrir(tester, orcamentos: [total(50000)], gastoMesCent: 42000);
        expect(
          find.text(
            'Orçamento: faltam ${formatarCent(8000)} · '
            'depois da lista: ${formatarCent(8000 - 783)}',
          ),
          findsOneWidget,
        );
      });

      testWidgets('sem orçamento não mostra a linha', (tester) async {
        await abrir(tester, gastoMesCent: 42000);
        expect(find.textContaining('Orçamento:'), findsNothing);
      });

      testWidgets('a lista passa o que falta: negativo e em erro', (
        tester,
      ) async {
        await abrir(tester, orcamentos: [total(42500)], gastoMesCent: 42000);
        final texto =
            'Orçamento: faltam ${formatarCent(500)} · '
            'depois da lista: −${formatarCent(283)}';
        expect(find.text(texto), findsOneWidget);
        final cor = tester.widget<Text>(find.text(texto)).style?.color;
        expect(
          cor,
          Theme.of(tester.element(find.text(texto))).colorScheme.error,
        );
      });
    });
  });
}

/// Lista em memória que regista as chamadas e emite as alterações.
class _ListaFalsa implements ListaRepository {
  _ListaFalsa(List<ItemLista> inicial) : _itens = [...inicial];

  final List<ItemLista> _itens;
  final chamadas = <String>[];
  final _c = StreamController<List<ItemLista>>.broadcast();

  void _mudar(ItemLista item, ItemLista novo) {
    final i = _itens.indexWhere(
      (x) => x.lojaId == item.lojaId && x.artigoId == item.artigoId,
    );
    _itens[i] = novo;
    _c.add([..._itens]);
  }

  @override
  Stream<List<ItemLista>> observarItens() async* {
    yield [..._itens];
    yield* _c.stream;
  }

  @override
  Future<void> marcarComprado(ItemLista item, {required bool comprado}) async {
    chamadas.add('comprado ${item.artigoId} $comprado');
    _mudar(item, item.copyWith(comprado: comprado));
  }

  @override
  Future<void> definirIncluido(ItemLista item, {required bool incluido}) async {
    chamadas.add('incluido ${item.artigoId} $incluido');
    _mudar(item, item.copyWith(incluido: incluido, comprado: false));
  }

  @override
  Future<void> repor(ItemLista anterior) async {
    chamadas.add('repor ${anterior.artigoId}');
    _mudar(anterior, anterior);
  }

  @override
  Future<void> alterarQtd(ItemLista item, num qtd) async =>
      chamadas.add('qtd ${item.artigoId} $qtd');

  @override
  Future<void> alterarQtdPadrao(ItemLista item, num qtd) async =>
      chamadas.add('padrao ${item.artigoId} $qtd');

  @override
  Future<void> incluir({
    required String lojaId,
    required String artigoId,
    num? qtd,
  }) async => chamadas.add('incluir $artigoId');
}

class _PreferenciasFalsas implements PreferenciasRepository {
  _PreferenciasFalsas(this.atual);

  Preferencias atual;
  final _c = StreamController<Preferencias>.broadcast();

  @override
  Stream<Preferencias> observar() async* {
    yield atual;
    yield* _c.stream;
  }

  @override
  Future<void> guardar(Preferencias p) async {
    atual = p;
    _c.add(p);
  }
}
