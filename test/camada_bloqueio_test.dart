import 'package:cabaz_mensal/core/desbloqueio.dart';
import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/features/bloqueio/camada_bloqueio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Só o que o "Sair" usa.
class _FakeSync implements SyncRepository {
  _FakeSync(this.base);
  final BaseLocal base;

  @override
  Future<void> limparLocal() => base.limparTudo();

  @override
  Stream<EstadoSync> observarEstado() => Stream.value(const EstadoSync());

  @override
  Stream<List<AlteracaoPendente>> observarPendentes() => const Stream.empty();

  @override
  Future<void> sincronizar() async {}

  @override
  Future<void> descartar(int id) async {}

  @override
  Future<void> recarregarTudo({bool descartarPendentes = false}) async {}
}

void main() {
  late BaseLocal base;
  late FakeDesbloqueio desbloqueio;
  late FakeAuthRepository auth;
  late DateTime agora;

  setUp(() {
    base = BaseLocal(NativeDatabase.memory());
    desbloqueio = FakeDesbloqueio();
    auth = FakeAuthRepository();
    agora = DateTime(2026, 10, 30, 12);
  });
  tearDown(() => base.close());

  Future<void> abrir(WidgetTester t, {bool ligado = true}) async {
    if (ligado) await base.gravarEstado('bloqueio', 'sim');
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          baseLocalProvider.overrideWithValue(base),
          desbloqueioProvider.overrideWithValue(desbloqueio),
          authRepositoryProvider.overrideWithValue(auth),
          syncRepositoryProvider.overrideWithValue(_FakeSync(base)),
          estadoSyncProvider.overrideWith(
            (_) => Stream.value(const EstadoSync()),
          ),
          agoraProvider.overrideWithValue(() => agora),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          builder: (_, filho) => CamadaBloqueio(child: filho!),
          home: const Scaffold(body: Text('conteúdo')),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  final conteudo = find.text('conteúdo');
  final bloqueada = find.text('A app está bloqueada.');

  /// Sai da app e volta passado [fora].
  Future<void> sairEVoltar(WidgetTester t, Duration fora) async {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    agora = agora.add(fora);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.pumpAndSettle();
  }

  testWidgets('bloqueio desligado: não bloqueia nem pede', (t) async {
    await abrir(t, ligado: false);
    expect(conteudo, findsOneWidget);
    expect(desbloqueio.pedidos, 0);
  });

  testWidgets('sem sessão: não bloqueia', (t) async {
    auth = FakeAuthRepository(comSessao: false);
    await abrir(t);
    expect(conteudo, findsOneWidget);
    expect(desbloqueio.pedidos, 0);
  });

  testWidgets('ao abrir: bloqueia, pede logo e desbloqueia', (t) async {
    await abrir(t);
    expect(desbloqueio.pedidos, 1);
    expect(conteudo, findsOneWidget);
    expect(bloqueada, findsNothing);
  });

  testWidgets('cancelar mantém bloqueada; Desbloquear pede outra vez', (
    t,
  ) async {
    desbloqueio.resposta = false;
    await abrir(t);
    expect(bloqueada, findsOneWidget);
    expect(conteudo, findsNothing);

    desbloqueio.resposta = true;
    await t.tap(find.text('Desbloquear'));
    await t.pumpAndSettle();
    expect(desbloqueio.pedidos, 2);
    expect(conteudo, findsOneWidget);
  });

  testWidgets('erro do desbloqueio: mostra a mensagem', (t) async {
    desbloqueio.erro = const ErroDesbloqueio('Demasiadas tentativas.');
    await abrir(t);
    expect(bloqueada, findsOneWidget);
    expect(find.text('Demasiadas tentativas.'), findsOneWidget);
  });

  testWidgets('voltar antes dos 5 minutos não bloqueia; depois bloqueia', (
    t,
  ) async {
    await abrir(t);
    expect(desbloqueio.pedidos, 1);

    await sairEVoltar(t, const Duration(minutes: 4, seconds: 59));
    expect(desbloqueio.pedidos, 1);
    expect(conteudo, findsOneWidget);

    desbloqueio.resposta = false;
    await sairEVoltar(t, tempoFora);
    expect(desbloqueio.pedidos, 2);
    expect(bloqueada, findsOneWidget);
  });

  testWidgets('Sair no ecrã de bloqueio termina a sessão e desliga', (t) async {
    desbloqueio.resposta = false;
    await abrir(t);
    await t.tap(find.text('Sair'));
    await t.pumpAndSettle();
    expect(auth.temSessao, isFalse);
    expect(bloqueada, findsNothing);
    expect(await base.lerEstado('bloqueio'), isNull);
  });
}
