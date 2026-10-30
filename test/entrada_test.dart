import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/features/entrada/entrada_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('o olho mostra e volta a esconder a palavra-passe', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(comSessao: false),
          ),
        ],
        child: const MaterialApp(home: EntradaPage()),
      ),
    );
    bool escondida() => t
        .widget<EditableText>(
          find.descendant(
            of: find.widgetWithText(TextFormField, 'Palavra-passe'),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(escondida(), isTrue);
    await t.tap(find.byTooltip('Mostrar palavra-passe'));
    await t.pump();
    expect(escondida(), isFalse);
    await t.tap(find.byTooltip('Esconder palavra-passe'));
    await t.pump();
    expect(escondida(), isTrue);
  });
}
