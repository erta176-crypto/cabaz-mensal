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
}
