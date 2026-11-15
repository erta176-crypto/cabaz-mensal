import 'dart:async';

import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/data/supabase/base.dart';
import 'package:flutter_test/flutter_test.dart';

const _curto = Duration(milliseconds: 20);

Future<int> _nuncaResponde() => Completer<int>().future;

void main() {
  test('escrita que não responde dá ErroSemResposta', () {
    expect(
      escreverComLimite(_nuncaResponde, limite: _curto),
      throwsA(isA<ErroSemResposta>()),
    );
  });

  test('ErroSemResposta é um ErroDados com a mensagem da D4', () {
    const e = ErroSemResposta();
    expect(e, isA<ErroDados>());
    expect(e.mensagem, contains('pode ter ficado gravada'));
  });

  test('escrita com êxito devolve o valor', () async {
    expect(await escreverComLimite(() async => 7, limite: _curto), 7);
  });

  test('leitura que não responde dá "sem rede"', () {
    expect(
      lerComRede(_nuncaResponde, limite: _curto, semRede: 'Sem rede: x'),
      throwsA(
        isA<ErroDados>()
            .having((e) => e.mensagem, 'mensagem', 'Sem rede: x')
            .having((e) => e is ErroSemResposta, 'semResposta', isFalse),
      ),
    );
  });

  test('leitura com erro de rede dá "sem rede"', () {
    expect(
      lerComRede<int>(
        () async => throw Exception('ClientException: sem ligação'),
        semRede: 'Sem rede: x',
      ),
      throwsA(isA<ErroDados>().having((e) => e.mensagem, 'm', 'Sem rede: x')),
    );
  });

  test('leitura deixa passar um ErroDados', () {
    expect(
      lerComRede<int>(
        () async => throw const ErroDados('Já existem dados.'),
        semRede: 'Sem rede: x',
      ),
      throwsA(
        isA<ErroDados>().having((e) => e.mensagem, 'm', 'Já existem dados.'),
      ),
    );
  });

  group('leituras por páginas', () {
    const pagina = Duration(milliseconds: 25);
    const limite = Duration(milliseconds: 40);

    // 3 páginas de 2 linhas e uma última de 1; cada página demora 25 ms.
    Future<List<Map<String, dynamic>>> lerPaginas() => buscarPaginas(
      (inicio, fim) async {
        await Future<void>.delayed(pagina);
        final total = 7;
        return [
          for (var i = inicio; i <= fim && i < total; i++) {'n': i},
        ];
      },
      limite: limite,
      tamanho: 2,
    );

    test('com limite global, várias páginas lentas dão sem rede', () {
      expect(
        lerComRede(lerPaginas, limite: limite, semRede: 'Sem rede: x'),
        throwsA(isA<ErroDados>().having((e) => e.mensagem, 'm', 'Sem rede: x')),
      );
    });

    test('sem limite global, devolve todas as linhas', () async {
      final r = await lerComRede(
        lerPaginas,
        limite: null,
        semRede: 'Sem rede: x',
      );
      expect(r, hasLength(7));
    });

    test('página que nunca responde dá "sem rede"', () {
      expect(
        lerComRede(
          () => buscarPaginas(
            (_, _) => Completer<List<Map<String, dynamic>>>().future,
            limite: limite,
            tamanho: 2,
          ),
          limite: null,
          semRede: 'Sem rede: x',
        ),
        throwsA(isA<ErroDados>().having((e) => e.mensagem, 'm', 'Sem rede: x')),
      );
    });

    test('ErroDados de uma página passa tal e qual', () {
      expect(
        lerComRede(
          () => buscarPaginas(
            (_, _) async => throw const ErroDados('Sessão terminou.'),
            tamanho: 2,
          ),
          limite: null,
          semRede: 'Sem rede: x',
        ),
        throwsA(
          isA<ErroDados>().having((e) => e.mensagem, 'm', 'Sessão terminou.'),
        ),
      );
    });
  });
}
