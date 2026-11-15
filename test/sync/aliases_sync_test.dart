import 'dart:async';

import 'package:cabaz_mensal/data/sync/servidor.dart';
import 'package:cabaz_mensal/data/sync/servidor_supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dispositivo.dart';
import 'servidor_falso.dart';

void main() {
  test(
    'guardarAlias sem rede sincroniza depois e chega ao outro aparelho',
    () async {
      final servidor = ServidorFalso();
      final telemovel = Dispositivo(servidor);
      final pc = Dispositivo(servidor);
      addTearDown(() async {
        await telemovel.fechar();
        await pc.fechar();
      });

      servidor.online = false;
      await telemovel.artigos.guardarAlias(
        'loja-lidl',
        'SALADA COM COENTROS',
        'a1',
      );
      expect(await telemovel.artigos.observarAliases().first, {
        'a1': ['SALADA COM COENTROS'],
      });

      servidor.online = true;
      await telemovel.sincronizar();
      expect(
        servidor.t('aliases').single['texto_talao'],
        'SALADA COM COENTROS',
      );
      expect(servidor.t('aliases').single['loja_id'], 'loja-lidl');

      await pc.sincronizar();
      expect(await pc.artigos.observarAliases().first, {
        'a1': ['SALADA COM COENTROS'],
      });

      // Gravar o mesmo alias outra vez não duplica.
      await telemovel.artigos.guardarAlias(
        'loja-lidl',
        'SALADA COM COENTROS',
        'a1',
      );
      await telemovel.sincronizar();
      expect(servidor.t('aliases'), hasLength(1));
    },
  );

  test('muito tempo sem rede: o alias continua na fila, sem erro', () async {
    final servidor = ServidorFalso();
    final telemovel = Dispositivo(servidor);
    addTearDown(telemovel.fechar);

    servidor.online = false;
    await telemovel.artigos.guardarAlias('loja-lidl', 'SALADA', 'a1');
    // Mais tentativas do que o limite do Sincronizador (20).
    for (var i = 0; i < 25; i++) {
      await expectLater(telemovel.sync.enviar(), throwsA(isA<ErroSync>()));
    }
    final fila = await telemovel.base.observarPendentes().first;
    expect(fila.single.erro, isNull);
    expect(fila.single.tentativas, 0);

    servidor.online = true;
    await telemovel.sincronizar();
    expect(servidor.t('aliases').single['texto_talao'], 'SALADA');
  });

  test(
    'servidor sempre com erro transitório: ao fim de 20 fica com erro',
    () async {
      final servidor = ServidorFalso()..indisponivel = true;
      final telemovel = Dispositivo(servidor);
      addTearDown(telemovel.fechar);

      await telemovel.artigos.guardarAlias('loja-lidl', 'SALADA', 'a1');
      for (var i = 0; i < 19; i++) {
        await expectLater(telemovel.sync.enviar(), throwsA(isA<ErroSync>()));
      }
      // A 20.ª tentativa marca o erro e deixa a fila andar.
      await telemovel.sync.enviar();
      final fila = await telemovel.base.observarPendentes().first;
      expect(fila.single.erro, contains('503'));
    },
  );

  group('classificarErro', () {
    test('falha de rede ao renovar a sessão: sem rede', () {
      final e = classificarErro(
        AuthRetryableFetchException(
          message: 'ClientException with SocketException: Failed host lookup',
        ),
      );
      expect(e.transitorio, isTrue);
      expect(e.semRede, isTrue);
    });

    test('5xx ao renovar a sessão: transitório, mas não é falta de rede', () {
      final e = classificarErro(
        AuthRetryableFetchException(message: 'x', statusCode: '503'),
      );
      expect(e.transitorio, isTrue);
      expect(e.semRede, isFalse);
    });

    test('sessão recusada pelo servidor: permanente', () {
      final e = classificarErro(AuthApiException('Invalid Refresh Token'));
      expect(e.transitorio, isFalse);
      expect(e.semRede, isFalse);
    });

    test('exceção de rede genérica: sem rede', () {
      final e = classificarErro(TimeoutException('20 s'));
      expect(e.semRede, isTrue);
    });

    test('erro do Postgres: nunca é falta de rede', () {
      final e = classificarErro(
        const PostgrestException(message: 'x', code: '57014'),
      );
      expect(e.transitorio, isTrue);
      expect(e.semRede, isFalse);
    });
  });
}
