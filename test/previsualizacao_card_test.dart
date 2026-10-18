import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/features/importar_exportar/previsualizacao_card.dart';
import 'package:cabaz_mensal/import/campos.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/tabela_lida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tabela = TabelaLida(
  cabecalhos: ['Artigo', 'PVP'],
  linhas: [
    ['Kiwi', '3,49'],
    ['', '1'],
  ],
);

final previa = Previsualizacao(
  linhas: const [
    LinhaPrevia(numero: 1, valores: ['Kiwi', '3,49'], estado: EstadoLinha.novo),
    LinhaPrevia(
      numero: 2,
      valores: ['', '1'],
      estado: EstadoLinha.erro,
      motivo: 'Artigo vazio',
    ),
  ],
  lote: LoteImportacao(),
);

Future<void> abrir(
  WidgetTester tester, {
  required bool online,
  void Function(int, Campo)? aoMudar,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: construirTema(Brightness.light, fontesGoogle: false),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrevisualizacaoCard(
            nomeFicheiro: 'artigos.csv',
            tabela: tabela,
            tipo: TipoImportacao.artigos,
            campos: const [Campo.artigo, Campo.preco],
            previa: previa,
            aoMudarCampo: aoMudar ?? (_, _) {},
            opcoes: const [],
            online: online,
            aGravar: false,
            aoImportar: () {},
            aoCancelar: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton botao(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Importar 1 linha'),
);

void main() {
  testWidgets('sem rede: botão desativado e explicação', (tester) async {
    await abrir(tester, online: false);
    expect(botao(tester).onPressed, isNull);
    expect(find.textContaining('Sem rede'), findsOneWidget);
    expect(find.text('2 linhas: 1 novas, 1 com erro'), findsOneWidget);
    expect(find.textContaining('Erro · Artigo vazio'), findsOneWidget);
  });

  testWidgets('com rede: botão ativo, sem a explicação', (tester) async {
    await abrir(tester, online: true);
    expect(botao(tester).onPressed, isNotNull);
    expect(find.textContaining('Sem rede'), findsNothing);
  });

  testWidgets('mudar o menu de uma coluna avisa o ecrã', (tester) async {
    (int, Campo)? mudado;
    await abrir(tester, online: true, aoMudar: (i, c) => mudado = (i, c));
    await tester.tap(find.byKey(const ValueKey('coluna-1-Campo.preco')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ignorar').last);
    await tester.pumpAndSettle();
    expect(mudado, (1, Campo.ignorar));
  });
}
