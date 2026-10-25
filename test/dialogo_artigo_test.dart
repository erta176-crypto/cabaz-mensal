import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/artigos/artigos_page.dart';
import 'package:cabaz_mensal/features/artigos/dialogos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const ovos = Artigo(
  id: 'a-ovos',
  nome: 'Ovos',
  categoriaId: null,
  unidade: Unidade.un,
  ean: '5601312509769',
);
const leite = Artigo(
  id: 'a-leite',
  nome: 'Leite',
  categoriaId: null,
  unidade: Unidade.un,
);

Future<void> abrir(WidgetTester tester, Artigo artigo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        artigosProvider.overrideWith((ref) => Stream.value([ovos, leite])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DialogoArtigo(
            artigo: artigo,
            categorias: const [],
            lojas: const [],
            precosAtuais: const {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder campoEan() =>
    find.widgetWithText(TextFormField, 'Código de barras (opcional)');

void main() {
  testWidgets('avisa quando o código já está noutro artigo', (tester) async {
    await abrir(tester, leite);
    await tester.enterText(campoEan(), '5601312509769');
    await tester.pump();
    expect(find.text('Este código já está no artigo "Ovos".'), findsOneWidget);
  });

  testWidgets('recusa gravar um código que já está noutro artigo', (
    tester,
  ) async {
    await abrir(tester, leite);
    await tester.enterText(campoEan(), '5601312509769');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(DialogoArtigo), findsOneWidget, reason: 'não fecha');
    expect(find.text('Este código já está no artigo "Ovos".'), findsOneWidget);
  });

  testWidgets('não avisa no próprio artigo', (tester) async {
    await abrir(tester, ovos);
    expect(find.textContaining('Este código já está'), findsNothing);
  });

  test('a pesquisa encontra pelo nome ou pelo código de barras', () {
    expect(artigoCorresponde(ovos, '5601312509769'), isTrue);
    expect(artigoCorresponde(ovos, '560131'), isTrue);
    expect(artigoCorresponde(ovos, 'ovo'), isTrue);
    expect(artigoCorresponde(leite, '5601312509769'), isFalse);
    expect(artigoCorresponde(leite, ''), isTrue);
  });
}
