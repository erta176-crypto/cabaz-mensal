import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/domain/texto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dispositivo.dart';
import 'servidor_falso.dart';

/// Laticínios e Fruta ativas, Limpeza apagada; Iogurte em Laticínios e
/// Banana em Fruta.
void _semear(ServidorFalso s) {
  for (final (id, nome, apagada) in [
    ('cat-lat', 'Laticínios', false),
    ('cat-fruta', 'Fruta', false),
    ('cat-limpeza', 'Limpeza', true),
  ]) {
    s.escreverDireto('categorias', {
      'id': id,
      'nome': nome,
      'ordem': 1,
      'apagado_em': apagada ? '2026-10-01T00:00:00Z' : null,
    });
  }
  for (final (id, nome, cat) in [
    ('art-iogurte', 'Iogurte', 'cat-lat'),
    ('art-banana', 'Banana', 'cat-fruta'),
  ]) {
    s.escreverDireto('artigos', {
      'id': id,
      'nome': nome,
      'categoria_id': cat,
      'unidade': 'un',
      'ativo': true,
    });
  }
}

void main() {
  late ServidorFalso servidor;
  late Dispositivo telemovel;

  setUp(() async {
    servidor = ServidorFalso();
    _semear(servidor);
    telemovel = Dispositivo(servidor);
    addTearDown(telemovel.fechar);
    await telemovel.sincronizar();
  });

  Future<Categoria> categoria(String id) async =>
      (await telemovel.categorias.observarCategorias().first).singleWhere(
        (c) => c.id == id,
      );

  Future<int> naFila() async =>
      (await telemovel.base.observarPendentes().first).length;

  group('renomear', () {
    test('para o nome de outra ativa (maiúsculas e acentos): recusa e não '
        'põe nada na fila', () async {
      final fruta = await categoria('cat-fruta');
      await expectLater(
        telemovel.categorias.atualizar(fruta.copyWith(nome: ' LATICINIOS ')),
        throwsA(
          isA<ErroNomeRepetido>()
              .having((e) => e.existente.id, 'existente', 'cat-lat')
              .having((e) => e.apagada, 'apagada', isFalse),
        ),
      );
      expect(await naFila(), 0);
      expect((await categoria('cat-fruta')).nome, 'Fruta');
    });

    test('para o nome de uma apagada: recusa e diz qual', () async {
      final fruta = await categoria('cat-fruta');
      await expectLater(
        telemovel.categorias.atualizar(fruta.copyWith(nome: 'limpeza')),
        throwsA(
          isA<ErroNomeRepetido>()
              .having((e) => e.existente.id, 'existente', 'cat-limpeza')
              .having((e) => e.apagada, 'apagada', isTrue),
        ),
      );
      expect(await naFila(), 0);
    });

    test('nome vazio: recusa', () async {
      final fruta = await categoria('cat-fruta');
      await expectLater(
        telemovel.categorias.atualizar(fruta.copyWith(nome: '   ')),
        throwsA(isA<ErroDados>()),
      );
      expect(await naFila(), 0);
    });

    test('só maiúsculas ou espaços da própria: grava, sem espaços, e chega '
        'ao servidor', () async {
      final fruta = await categoria('cat-fruta');
      await telemovel.categorias.atualizar(fruta.copyWith(nome: ' FRUTA '));
      await telemovel.sincronizar();
      final noServidor = servidor
          .t('categorias')
          .singleWhere((c) => c['id'] == 'cat-fruta');
      expect(noServidor['nome'], 'FRUTA');
      expect(await naFila(), 0);
    });
  });

  group('criar', () {
    test('nome de uma ativa com outras maiúsculas: recusa', () async {
      await expectLater(
        telemovel.categorias.criar(nome: 'fruta', ordem: 5),
        throwsA(isA<ErroNomeRepetido>()),
      );
      expect(await naFila(), 0);
    });

    test('nome de uma apagada com outras maiúsculas: reativa a mesma linha '
        'e o servidor aceita', () async {
      await telemovel.categorias.criar(nome: ' LIMPEZA ', ordem: 5);
      await telemovel.sincronizar();
      final limpeza = servidor
          .t('categorias')
          .where((c) => normalizar(c['nome'] as String) == 'limpeza');
      expect(limpeza.single['id'], 'cat-limpeza');
      expect(limpeza.single['apagado_em'], isNull);
      expect(limpeza.single['nome'], 'LIMPEZA');
      expect(await naFila(), 0);
    });
  });

  group('juntar', () {
    test('move os artigos para o destino, apaga a origem e chega ao outro '
        'aparelho', () async {
      final pc = Dispositivo(servidor);
      addTearDown(pc.fechar);

      await telemovel.categorias.juntar('cat-fruta', 'cat-lat');
      await telemovel.sincronizar();
      await pc.sincronizar();

      final artigos = await pc.artigos.observarArtigos().first;
      expect(
        artigos.singleWhere((a) => a.id == 'art-banana').categoriaId,
        'cat-lat',
      );
      final categorias = await pc.categorias.observarCategorias().first;
      expect([for (final c in categorias) c.id], ['cat-lat']);
      expect(await naFila(), 0);
    });

    test('para uma apagada: reativa-a e junta', () async {
      await telemovel.categorias.juntar('cat-fruta', 'cat-limpeza');
      await telemovel.sincronizar();

      final categorias = await telemovel.categorias.observarCategorias().first;
      expect({for (final c in categorias) c.id}, {'cat-lat', 'cat-limpeza'});
      final artigos = await telemovel.artigos.observarArtigos().first;
      expect(
        artigos.singleWhere((a) => a.id == 'art-banana').categoriaId,
        'cat-limpeza',
      );
      expect(await naFila(), 0);
    });
  });

  test('servidor falso: o índice do nome inclui as apagadas, como o real '
      '(categorias_user_id_nome_key)', () async {
    // Escrita que não passa pelo repositório (ex.: fila antiga).
    final fruta = await categoria('cat-fruta');
    await telemovel.escrita.atualizar('categorias', fruta.id, {
      'nome': 'Limpeza',
    });
    await expectLater(telemovel.sync.enviar(), completes);
    final fila = await telemovel.base.observarPendentes().first;
    expect(fila.single.erro, contains('23505'));
  });
}
