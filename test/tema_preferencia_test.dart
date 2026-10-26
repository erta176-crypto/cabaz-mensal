import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/domain/preferencias.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BaseLocal base;

  setUp(() => base = BaseLocal(NativeDatabase.memory()));
  tearDown(() => base.close());

  Future<ModoTema> lido() async {
    final c = ProviderContainer(
      overrides: [baseLocalProvider.overrideWithValue(base)],
    );
    addTearDown(c.dispose);
    c.read(temaProvider);
    await pumpEventQueue();
    return c.read(temaProvider);
  }

  test('por omissão segue o sistema', () async {
    expect(await lido(), ModoTema.sistema);
  });

  test('escolher grava e um arranque novo lê a escolha', () async {
    final c = ProviderContainer(
      overrides: [baseLocalProvider.overrideWithValue(base)],
    );
    addTearDown(c.dispose);
    await c.read(temaProvider.notifier).escolher(ModoTema.escuro);
    expect(c.read(temaProvider), ModoTema.escuro);
    expect(await base.lerEstado('tema'), 'escuro');
    expect(await lido(), ModoTema.escuro);
  });

  test('valor desconhecido → sistema', () async {
    await base.gravarEstado('tema', 'roxo');
    expect(await lido(), ModoTema.sistema);
  });

  test('limparTudo mantém o tema e apaga o resto', () async {
    await base.gravarEstado('tema', 'claro');
    await base.gravarEstado('utilizador', 'u1');
    await base.limparTudo();
    expect(await base.lerEstado('tema'), 'claro');
    expect(await base.lerEstado('utilizador'), isNull);
  });

  test('limparCache mantém o tema', () async {
    await base.gravarEstado('tema', 'escuro');
    await base.limparCache();
    expect(await base.lerEstado('tema'), 'escuro');
  });
}
