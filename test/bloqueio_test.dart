import 'package:cabaz_mensal/core/desbloqueio.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/preferencias.dart';
import 'package:cabaz_mensal/features/definicoes/definicoes_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Desbloqueio falso: [resposta] é o resultado de cada pedido.
class FakeDesbloqueio implements Desbloqueio {
  FakeDesbloqueio({this.disponivelNoAparelho = true, this.resposta = true});
  final bool disponivelNoAparelho;
  bool resposta;
  int pedidos = 0;

  @override
  Future<bool> disponivel() async => disponivelNoAparelho;

  @override
  Future<bool> pedir() async {
    pedidos++;
    return resposta;
  }
}

void main() {
  late BaseLocal base;

  setUp(() => base = BaseLocal(NativeDatabase.memory()));
  tearDown(() => base.close());

  ProviderContainer contentor(Desbloqueio d) {
    final c = ProviderContainer(
      overrides: [
        baseLocalProvider.overrideWithValue(base),
        desbloqueioProvider.overrideWithValue(d),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('BloqueioNotifier', () {
    test('desligado por omissão', () async {
      expect(
        await contentor(FakeDesbloqueio()).read(bloqueioProvider.future),
        isFalse,
      );
    });

    test('ligar pede o desbloqueio e grava; um arranque novo lê-o', () async {
      final d = FakeDesbloqueio();
      final c = contentor(d);
      expect(await c.read(bloqueioProvider.notifier).ligar(), isTrue);
      expect(d.pedidos, 1);
      expect(c.read(bloqueioProvider).value, isTrue);
      expect(await base.lerEstado('bloqueio'), 'sim');
      expect(await contentor(d).read(bloqueioProvider.future), isTrue);
    });

    test('desbloqueio cancelado não liga', () async {
      final c = contentor(FakeDesbloqueio(resposta: false));
      await c.read(bloqueioProvider.future);
      expect(await c.read(bloqueioProvider.notifier).ligar(), isFalse);
      expect(c.read(bloqueioProvider).value, isFalse);
      expect(await base.lerEstado('bloqueio'), isNull);
    });

    test('desligar não pede nada e apaga', () async {
      await base.gravarEstado('bloqueio', 'sim');
      final d = FakeDesbloqueio();
      final c = contentor(d);
      await c.read(bloqueioProvider.future);
      await c.read(bloqueioProvider.notifier).desligar();
      expect(d.pedidos, 0);
      expect(c.read(bloqueioProvider).value, isFalse);
      expect(await base.lerEstado('bloqueio'), isNull);
    });

    test('sair da conta (limparTudo) desliga o bloqueio', () async {
      await base.gravarEstado('bloqueio', 'sim');
      await base.limparTudo();
      expect(await base.lerEstado('bloqueio'), isNull);
    });
  });

  group('Definições', () {
    Future<void> abrir(WidgetTester t, FakeDesbloqueio d) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            baseLocalProvider.overrideWithValue(base),
            desbloqueioProvider.overrideWithValue(d),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            preferenciasProvider.overrideWith(
              (_) => Stream.value(const Preferencias()),
            ),
            estadoSyncProvider.overrideWith(
              (_) => Stream.value(const EstadoSync()),
            ),
          ],
          child: MaterialApp(
            theme: construirTema(Brightness.light, fontesGoogle: false),
            home: const DefinicoesPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    final interruptor = find.widgetWithText(
      SwitchListTile,
      'Bloquear com impressão digital ou PIN',
    );

    testWidgets('sem suporte no aparelho (ou na web) não aparece', (t) async {
      await abrir(t, FakeDesbloqueio(disponivelNoAparelho: false));
      expect(interruptor, findsNothing);
    });

    testWidgets('ligar e desligar pelo interruptor', (t) async {
      final d = FakeDesbloqueio();
      await abrir(t, d);
      expect(t.widget<SwitchListTile>(interruptor).value, isFalse);
      await t.tap(interruptor);
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(interruptor).value, isTrue);
      expect(d.pedidos, 1);
      await t.tap(interruptor);
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(interruptor).value, isFalse);
      expect(d.pedidos, 1);
    });

    testWidgets('desbloqueio cancelado deixa o interruptor desligado', (
      t,
    ) async {
      final d = FakeDesbloqueio(resposta: false);
      await abrir(t, d);
      await t.tap(interruptor);
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(interruptor).value, isFalse);
    });
  });
}
