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
    File('test/fixtures/taloes/$nome.txt').readAsStringSync();

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
      (ficheiro: 'x.pdf', texto: 'MERCADONA'),
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
              escolhas: const {},
              nomesArtigos: const {'a-bife': 'Bife de frango'},
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
}
