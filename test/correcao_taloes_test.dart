import 'dart:io';

import 'package:cabaz_mensal/core/formatos.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/importar_exportar/previsualizacao_taloes.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/taloes/importar_taloes.dart';
import 'package:cabaz_mensal/import/taloes/talao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

String _f(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

final _cat = Catalogo(
  lojas: const [Loja(id: 'lidl', slug: 'lidl', nome: 'Lidl')],
  categorias: const [],
  artigos: const [],
);

TalaoLido _lidl({String total = 'Total 14,77'}) => lerTaloes([
  (ficheiro: 'f', texto: _f('lidl').replaceFirst('Total 14,77', total)),
]).lidos.single.talao;

/// A pré-visualização com as correções ligadas, como na página: cada
/// edição volta a analisar o lote. [ultimo] guarda o talão corrigido.
class _Ecra extends StatefulWidget {
  const _Ecra({required this.talao, this.fotos = const {}, this.editar = true});
  final TalaoLido talao;
  final Map<String, String> fotos;
  final bool editar;

  static TalaoLido? ultimo;

  @override
  State<_Ecra> createState() => _EcraState();
}

class _EcraState extends State<_Ecra> {
  late TalaoLido _talao = widget.talao;

  @override
  Widget build(BuildContext context) {
    final r = analisarLidos([(ficheiro: 'f', talao: _talao)], _cat, const []);
    return PrevisualizacaoTaloes(
      taloes: r.taloes,
      naoReconhecidos: r.naoReconhecidos,
      escolhas: const {},
      nomesArtigos: const {},
      online: true,
      aGravar: false,
      aoImportar: () {},
      aoCancelar: () {},
      fotos: widget.fotos,
      aoEditar: !widget.editar
          ? null
          : (_, t) => setState(() => _talao = _Ecra.ultimo = t),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));
  setUp(() => _Ecra.ultimo = null);

  Future<void> abrir(
    WidgetTester t,
    TalaoLido talao, {
    Map<String, String> fotos = const {},
    bool editar = true,
  }) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light, fontesGoogle: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: _Ecra(talao: talao, fotos: fotos, editar: editar),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> menuDa(WidgetTester t, String texto, String acao) async {
    await t.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(texto),
          matching: find.byType(ListTile),
        ),
        matching: find.byTooltip('Ações da linha'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(acao));
    await t.pumpAndSettle();
  }

  Future<void> escrever(WidgetTester t, String rotulo, String texto) =>
      t.enterText(find.widgetWithText(TextField, rotulo), texto);

  Future<void> guardar(WidgetTester t) async {
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
  }

  testWidgets('corrigir o total passa de "A rever" a "Novo"', (t) async {
    await abrir(t, _lidl(total: 'Total 14,99'));
    expect(find.textContaining(RegExp(r'· A rever')), findsOneWidget);
    expect(
      find.text(
        'Soma das linhas ${formatarCent(1477)}; total ${formatarCent(1499)}.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Corrigir total e data'));
    await t.pumpAndSettle();
    await escrever(t, 'Total pago (€)', '14,77');
    await guardar(t);
    expect(_Ecra.ultimo!.totalCent, 1477);
    expect(find.textContaining(RegExp(r'· Novo$')), findsOneWidget);
    expect(find.textContaining('Soma das linhas'), findsNothing);
  });

  testWidgets('editar uma linha a peso: valor novo, peso e preço por kg', (
    t,
  ) async {
    await abrir(t, _lidl());
    await menuDa(t, 'BIFE DE FRANGO', 'Editar linha…');
    expect(find.text('Editar linha'), findsOneWidget);
    await escrever(t, 'Valor (€)', '4,00');
    await guardar(t);
    final l = _Ecra.ultimo!.linhas.firstWhere(
      (l) => l.texto == 'BIFE DE FRANGO',
    );
    expect((l.brutoCent, l.pesoG), (400, 519));
    expect(l.precoUnitCent, (400 * 1000 / 519).round());
    expect(find.text(formatarCent(400)), findsOneWidget);
    // A soma mudou: o talão passa a "A rever".
    expect(find.textContaining(RegExp(r'· A rever')), findsOneWidget);
  });

  testWidgets('apagar uma linha', (t) async {
    await abrir(t, _lidl());
    final antes = _lidl().linhas.length;
    await menuDa(t, 'BIFE DE FRANGO', 'Apagar linha');
    expect(_Ecra.ultimo!.linhas, hasLength(antes - 1));
    expect(find.text('BIFE DE FRANGO'), findsNothing);
  });

  testWidgets('acrescentar linha: valida e cria a linha a peso', (t) async {
    await abrir(t, _lidl());
    await t.tap(find.text('Acrescentar linha'));
    await t.pumpAndSettle();
    await escrever(t, 'Quantidade', '');
    await guardar(t);
    expect(find.text('Obrigatório'), findsOneWidget);
    expect(find.text('Quantidade inválida'), findsOneWidget);
    expect(find.text('Valor inválido'), findsOneWidget);

    await escrever(t, 'Texto do talão', 'CENOURA');
    await t.tap(find.text('Unidades'));
    await t.pumpAndSettle();
    await t.tap(find.text('Peso (kg)').last);
    await t.pumpAndSettle();
    await escrever(t, 'Peso (kg)', '0,5');
    await escrever(t, 'Valor (€)', '2,00');
    await guardar(t);
    final l = _Ecra.ultimo!.linhas.last;
    expect(
      (l.texto, l.quantidade, l.pesoG, l.brutoCent, l.precoUnitCent),
      ('CENOURA', null, 500, 200, 400),
    );
  });

  testWidgets('linha por reconhecer: acrescentar já preenchida', (t) async {
    await abrir(
      t,
      _lidl().copyWith(naoReconhecidas: ['XPTO 1,00 B', 'OUTRA COISA']),
    );
    expect(find.textContaining(RegExp(r'· A rever')), findsOneWidget);
    await t.tap(find.text('XPTO 1,00 B'));
    await t.pumpAndSettle();
    expect(find.text('Acrescentar linha').last, findsOneWidget);
    expect(find.widgetWithText(TextField, 'XPTO'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1,00'), findsOneWidget);
    await guardar(t);
    expect(_Ecra.ultimo!.naoReconhecidas, ['OUTRA COISA']);
    expect(_Ecra.ultimo!.linhas.last.texto, 'XPTO');
  });

  testWidgets('linha por reconhecer: ignorar', (t) async {
    await abrir(t, _lidl().copyWith(naoReconhecidas: ['OUTRA COISA']));
    expect(find.textContaining(RegExp(r'· A rever')), findsOneWidget);
    await t.tap(find.byTooltip('Ignorar'));
    await t.pumpAndSettle();
    expect(_Ecra.ultimo!.naoReconhecidas, isEmpty);
    expect(find.text('OUTRA COISA'), findsNothing);
    expect(find.textContaining(RegExp(r'· Novo$')), findsOneWidget);
  });

  testWidgets('"Ver fotografia" só nos talões com fotografia', (t) async {
    await abrir(t, _lidl());
    expect(find.text('Ver fotografia'), findsNothing);

    await abrir(t, _lidl(), fotos: {'f': 'nao-existe.jpg'});
    await t.tap(find.text('Ver fotografia'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await t.tap(find.byTooltip('Fechar'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('sem aoEditar não há correções', (t) async {
    await abrir(t, _lidl(total: 'Total 14,99'), editar: false);
    expect(find.text('Acrescentar linha'), findsNothing);
    expect(find.text('Corrigir total e data'), findsNothing);
    expect(find.byTooltip('Ações da linha'), findsNothing);
  });

  testWidgets('diálogo da linha sem transbordos: 360 px e letra ×2', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light, fontesGoogle: false),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => DialogoLinha(linha: _lidl().linhas.first),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
