import 'dart:io';

import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/importar_exportar/previsualizacao_taloes.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/taloes/importar_taloes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

String _f(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

const _bife = Artigo(
  id: 'a-bife',
  nome: 'Bife de frango',
  categoriaId: null,
  unidade: Unidade.kg,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  final analise = analisarTaloes(
    [
      (ficheiro: 'lidl.pdf', texto: _f('lidl')),
      (ficheiro: 'lidl (1).pdf', texto: _f('lidl')),
      (ficheiro: 'pd.pdf', texto: _f('pingo_doce')),
      (ficheiro: 'x.pdf', texto: 'CONTINENTE'),
    ],
    Catalogo(
      lojas: const [
        Loja(id: 'pd', slug: 'pingo-doce', nome: 'Pingo Doce'),
        Loja(id: 'lidl', slug: 'lidl', nome: 'Lidl'),
      ],
      categorias: const [],
      artigos: const [_bife],
    ),
    [
      CompraExistente(
        lojaId: 'pd',
        data: DateTime(2026, 10, 5),
        local: null,
        totalCent: 955,
      ),
    ],
  );

  Future<void> abrir(
    WidgetTester t, {
    bool online = true,
    VoidCallback? aoImportar,
    VoidCallback? aoCancelar,
    Map<String, EscolhaArtigo> escolhas = const {},
    void Function(String chave, EscolhaArtigo? escolha)? aoEscolher,
  }) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light, fontesGoogle: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrevisualizacaoTaloes(
              taloes: analise.taloes,
              naoReconhecidos: analise.naoReconhecidos,
              escolhas: escolhas,
              nomesArtigos: const {'a-bife': 'Bife de frango'},
              artigos: const [_bife],
              categorias: const [
                Categoria(id: 'c-peixe', nome: 'Peixe', ordem: 1),
              ],
              aoEscolher: aoEscolher,
              online: online,
              aGravar: false,
              aoImportar: aoImportar ?? () {},
              aoCancelar: aoCancelar ?? () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('resumo, estado de cada talão e não reconhecidos', (t) async {
    await abrir(t);
    expect(
      find.text(
        '3 talões: 1 novo, 1 já importado, 1 repetido neste lote '
        '· 1 não reconhecido',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Repetido neste lote'), findsOneWidget);
    expect(find.textContaining('Já importado'), findsOneWidget);
    expect(
      find.text('x.pdf: Formato de talão não reconhecido'),
      findsOneWidget,
    );
    expect(find.text('Importar 1 talão'), findsOneWidget);
  });

  testWidgets('linhas do talão novo: artigo existente e artigo novo', (
    t,
  ) async {
    await abrir(t);
    expect(find.text('BIFE DE FRANGO'), findsOneWidget);
    expect(find.text('0,519 kg · Bife de frango'), findsOneWidget);
    expect(find.text('3 un · Novo: Salada com coentros'), findsOneWidget);
    expect(find.text(formatarCent(387 - 78)), findsOneWidget);
  });

  testWidgets('Importar e Cancelar chamam as funções; sem rede desativa', (
    t,
  ) async {
    var importar = 0, cancelar = 0;
    await abrir(t, aoImportar: () => importar++, aoCancelar: () => cancelar++);
    await t.tap(find.text('Importar 1 talão'));
    await t.tap(find.text('Cancelar'));
    expect((importar, cancelar), (1, 1));

    await abrir(t, online: false);
    final botao = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Importar 1 talão'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(botao.onPressed, isNull);
    expect(
      find.text('Sem rede: a importação de talões precisa do servidor.'),
      findsOneWidget,
    );
  });

  group('menu das linhas novas (T6)', () {
    final salada = chaveEscolha('lidl', 'SALADA COM COENTROS');

    Future<void> abrirMenu(WidgetTester t) async {
      await t.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('SALADA COM COENTROS'),
            matching: find.byType(ListTile),
          ),
          matching: find.byTooltip('Ações da linha'),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('só as linhas com artigo novo têm o menu', (t) async {
      await abrir(t, aoEscolher: (_, _) {});
      // Linhas novas do Lidl: salada, pão, iogurte, marinadas, gelado.
      expect(find.byTooltip('Ações da linha'), findsNWidgets(5));
    });

    testWidgets('ligar a um artigo existente, com pesquisa', (t) async {
      final escolhas = <(String, EscolhaArtigo?)>[];
      await abrir(t, aoEscolher: (c, e) => escolhas.add((c, e)));
      await abrirMenu(t);
      await t.tap(find.text('Ligar a um artigo…'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'bife');
      await t.pumpAndSettle();
      await t.tap(find.text('Bife de frango').last);
      await t.pumpAndSettle();
      expect(escolhas.single.$1, salada);
      expect((escolhas.single.$2! as LigarArtigo).artigoId, 'a-bife');
    });

    testWidgets('mudar o nome do artigo novo', (t) async {
      final escolhas = <(String, EscolhaArtigo?)>[];
      await abrir(t, aoEscolher: (c, e) => escolhas.add((c, e)));
      await abrirMenu(t);
      await t.tap(find.text('Mudar o nome…'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Salada de coentros');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      final e = escolhas.single.$2! as NovoArtigo;
      expect(e.nome, 'Salada de coentros');
    });

    testWidgets('escolher a categoria do artigo novo', (t) async {
      final escolhas = <(String, EscolhaArtigo?)>[];
      await abrir(t, aoEscolher: (c, e) => escolhas.add((c, e)));
      await abrirMenu(t);
      await t.tap(find.text('Categoria…'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sem categoria').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Peixe').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      final e = escolhas.single.$2! as NovoArtigo;
      expect(e.nome, 'Salada com coentros');
      expect(e.categoriaId, 'c-peixe');
    });

    testWidgets('linha ligada mostra o artigo e tem Desfazer', (t) async {
      final escolhas = <(String, EscolhaArtigo?)>[];
      await abrir(
        t,
        escolhas: {salada: const LigarArtigo('a-bife')},
        aoEscolher: (c, e) => escolhas.add((c, e)),
      );
      expect(find.text('3 un · Bife de frango'), findsOneWidget);
      await abrirMenu(t);
      await t.tap(find.text('Desfazer'));
      await t.pumpAndSettle();
      expect(escolhas.single, (salada, null));
    });
  });
}
