import 'dart:async';

import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stream que só dá o valor depois de um momento, como a cache local.
Stream<T> _tarde<T>(T valor) async* {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  yield valor;
}

void main() {
  test('os providers do catálogo ainda sem valor: ler .value dá vazio, '
      'e carregarCatalogo espera por eles', () async {
    final c = ProviderContainer(
      overrides: [
        lojasProvider.overrideWith((_) => _tarde(const <Loja>[])),
        categoriasProvider.overrideWith((_) => _tarde(const <Categoria>[])),
        artigosProvider.overrideWith((_) => _tarde(const <Artigo>[])),
        aliasesProvider.overrideWith(
          (_) => _tarde(const {
            'a1': ['AZEITE FRESCO 750ML'],
          }),
        ),
        precosAtuaisProvider.overrideWith((_) => _tarde(const <PrecoAtual>[])),
        itensListaProvider.overrideWith((_) => _tarde(const <ItemLista>[])),
      ],
    );
    addTearDown(c.dispose);

    // O erro: sem ninguém a ouvir, o provider ainda não tem valor.
    expect(c.read(aliasesProvider).value, isNull);

    // O ecrã de importação ouve estes providers no build (providersDoCatalogo).
    for (final p in providersDoCatalogo) {
      c.listen(p, (_, _) {});
    }
    await carregarCatalogo(c.read);
    expect(c.read(aliasesProvider).value, {
      'a1': ['AZEITE FRESCO 750ML'],
    });
    expect(c.read(artigosProvider).hasValue, isTrue);
    expect(c.read(itensListaProvider).hasValue, isTrue);
  });
}
