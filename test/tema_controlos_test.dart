import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/domain/preferencias.dart';
import 'package:cabaz_mensal/features/shell/tema_controlos.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// App mínima com o themeMode ligado ao temaProvider, como em `app.dart`.
class _App extends ConsumerWidget {
  const _App(this.filho);
  final Widget filho;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: construirTema(Brightness.light, fontesGoogle: false),
    darkTheme: construirTema(Brightness.dark, fontesGoogle: false),
    themeMode: switch (ref.watch(temaProvider)) {
      ModoTema.sistema => ThemeMode.system,
      ModoTema.claro => ThemeMode.light,
      ModoTema.escuro => ThemeMode.dark,
    },
    home: Scaffold(body: Center(child: filho)),
  );
}

void main() {
  late BaseLocal base;
  setUp(() => base = BaseLocal(NativeDatabase.memory()));
  tearDown(() => base.close());

  Future<void> abrir(WidgetTester t, Widget filho) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [baseLocalProvider.overrideWithValue(base)],
        child: _App(filho),
      ),
    );
    await t.pumpAndSettle();
  }

  Brightness brilho(WidgetTester t) =>
      Theme.of(t.element(find.byType(Scaffold))).brightness;

  testWidgets('botão sol/lua alterna claro ↔ escuro', (t) async {
    await abrir(t, const BotaoTema());
    expect(brilho(t), Brightness.light);
    expect(find.byTooltip('Mudar para modo escuro'), findsOneWidget);
    expect(
      t.getSemantics(find.byType(IconButton)),
      containsSemantics(tooltip: 'Mudar para modo escuro', isButton: true),
    );

    await t.tap(find.byType(BotaoTema));
    await t.pumpAndSettle();
    expect(brilho(t), Brightness.dark);
    expect(find.byTooltip('Mudar para modo claro'), findsOneWidget);
    expect(await base.lerEstado('tema'), 'escuro');

    await t.tap(find.byType(BotaoTema));
    await t.pumpAndSettle();
    expect(brilho(t), Brightness.light);
  });

  testWidgets('botão tem área de toque ≥ 48 px', (t) async {
    await abrir(t, const BotaoTema());
    final tamanho = t.getSize(find.byType(IconButton));
    expect(tamanho.width, greaterThanOrEqualTo(48));
    expect(tamanho.height, greaterThanOrEqualTo(48));
  });

  testWidgets('menu Tema: escolher Escuro muda o tema', (t) async {
    await abrir(t, const SizedBox(width: 300, child: MenuTema()));
    expect(find.text('Sistema'), findsOneWidget);

    await t.tap(find.text('Sistema'));
    await t.pumpAndSettle();
    await t.tap(find.text('Escuro').last);
    await t.pumpAndSettle();
    expect(brilho(t), Brightness.dark);
    expect(await base.lerEstado('tema'), 'escuro');
  });
}
