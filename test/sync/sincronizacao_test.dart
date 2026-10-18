import 'package:cabaz_mensal/data/sync/servidor.dart';
import 'package:cabaz_mensal/domain/compra.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dispositivo.dart';
import 'servidor_falso.dart';

const lidl = 'loja-lidl';
const banana = 'artigo-banana';
const leite = 'artigo-leite';

/// Dados de partida no servidor, como depois da importação.
void semear(ServidorFalso s) {
  s.escreverDireto('lojas', {
    'id': lidl,
    'slug': 'lidl',
    'nome': 'Lidl',
    'arquivada': false,
  });
  s.escreverDireto('categorias', {'id': 'cat-fruta', 'nome': 'Fruta', 'ordem': 1});
  s.escreverDireto('artigos', {
    'id': banana,
    'nome': 'Banana',
    'categoria_id': 'cat-fruta',
    'unidade': 'kg',
    'ativo': true,
  });
  s.escreverDireto('artigos', {
    'id': leite,
    'nome': 'Leite',
    'categoria_id': null,
    'unidade': 'un',
    'ativo': true,
  });
  s.escreverDireto('itens_lista', {
    'id': 'item-servidor-1',
    'loja_id': lidl,
    'artigo_id': leite,
    'qtd_padrao': 2,
    'qtd': 2,
    'incluido': true,
    'comprado': false,
    'ordem': 0,
  });
}

Future<List<ItemLista>> itens(Dispositivo d) => d.lista.observarItens().first;

void main() {
  late ServidorFalso servidor;
  late Dispositivo telemovel;
  late Dispositivo pc;

  setUp(() async {
    servidor = ServidorFalso();
    semear(servidor);
    telemovel = Dispositivo(servidor);
    pc = Dispositivo(servidor);
    await telemovel.sincronizar();
    await pc.sincronizar();
  });

  tearDown(() async {
    await telemovel.fechar();
    await pc.fechar();
  });

  group('fila de alterações', () {
    test('repetir o envio da mesma operação não duplica', () async {
      await telemovel.lista.incluir(lojaId: lidl, artigoId: banana, qtd: 1.3);
      // A rede cai depois de o servidor gravar: o cliente volta a enviar.
      servidor.perderRespostas = 1;
      await expectLater(telemovel.sync.enviar(), throwsA(isA<ErroSync>()));
      expect(await telemovel.base.pendentesPorEnviar(), hasLength(1));
      await telemovel.sync.enviar();

      final noServidor = servidor
          .t('itens_lista')
          .where((i) => i['artigo_id'] == banana);
      expect(noServidor, hasLength(1));
      expect(await telemovel.base.pendentesPorEnviar(), isEmpty);
    });

    test('a ordem é respeitada', () async {
      final novo = Artigo(
        id: 'artigo-novo',
        nome: 'Teste sem rede',
        categoriaId: null,
        unidade: Unidade.un,
      );
      servidor.online = false;
      await telemovel.artigos.guardar(novo, novo: true);
      await telemovel.lista.incluir(lojaId: lidl, artigoId: novo.id);
      await telemovel.artigos.guardar(
        Artigo(
          id: novo.id,
          nome: 'Teste sem rede (editado)',
          categoriaId: null,
          unidade: Unidade.un,
        ),
      );
      servidor.online = true;
      await telemovel.sync.enviar();

      expect(servidor.chamadas, [
        'inserir artigos',
        'inserir itens_lista',
        'atualizar artigos',
      ]);
      final a = servidor.t('artigos').firstWhere((a) => a['id'] == novo.id);
      expect(a['nome'], 'Teste sem rede (editado)');
    });

    test('um erro permanente não bloqueia as seguintes', () async {
      servidor.recusar.add('categorias');
      await telemovel.categorias.criar(nome: 'Recusada', ordem: 9);
      await telemovel.lista.incluir(lojaId: lidl, artigoId: banana);
      await telemovel.sync.enviar();

      final fila = await telemovel.base.observarPendentes().first;
      expect(fila, hasLength(1));
      expect(fila.single.erro, contains('RLS'));
      expect(
        servidor.t('itens_lista').where((i) => i['artigo_id'] == banana),
        hasLength(1),
      );
    });

    test('sem rede a fila fica guardada', () async {
      servidor.online = false;
      final leiteItem = (await itens(telemovel)).single;
      await telemovel.lista.marcarComprado(leiteItem, comprado: true);
      await expectLater(telemovel.sync.enviar(), throwsA(isA<ErroSync>()));
      expect(await telemovel.base.pendentesPorEnviar(), hasLength(1));
      // Na cache já está marcado.
      expect((await itens(telemovel)).single.comprado, isTrue);
    });
  });

  group('receção', () {
    test('a margem de sobreposição não cria duplicados', () async {
      await telemovel.sincronizar();
      await telemovel.sincronizar();
      expect(await itens(telemovel), hasLength(1));
      expect(await telemovel.artigos.observarArtigos().first, hasLength(2));
    });

    test('uma linha apagada no servidor desaparece da cache', () async {
      await pc.artigos.eliminar(leite);
      await pc.sincronizar();
      await telemovel.sincronizar();
      final nomes = (await telemovel.artigos.observarArtigos().first)
          .map((a) => a.nome);
      expect(nomes, ['Banana']);
    });

    test('uma alteração local pendente não é substituída por dados antigos',
        () async {
      servidor.online = false;
      final item = (await itens(telemovel)).single;
      await telemovel.lista.alterarQtd(item, 7);
      servidor.online = true;
      // Puxar antes de enviar (ex.: o tempo real chegou primeiro).
      await telemovel.sync.puxar();
      expect((await itens(telemovel)).single.qtd, 7);
      await telemovel.sincronizar();
      expect((await itens(telemovel)).single.qtd, 7);
    });

    test('item criado sem rede fica com o id do servidor, sem duplicar',
        () async {
      await telemovel.lista.incluir(lojaId: lidl, artigoId: banana);
      final provisorio = (await itens(telemovel))
          .firstWhere((i) => i.artigoId == banana);
      expect(provisorio.id, isNull);
      await telemovel.sincronizar();
      final final_ = (await itens(telemovel))
          .where((i) => i.artigoId == banana)
          .toList();
      expect(final_, hasLength(1));
      expect(final_.single.id, isNotNull);
    });

    test('reiniciado_em (Apagar todos os dados) limpa a cache', () async {
      servidor.tabelas
        ..['artigos'] = []
        ..['itens_lista'] = [];
      servidor.escreverDireto('preferencias', {
        'user_id': 'u1',
        'dados': <String, dynamic>{},
        'reiniciado_em': servidor.tique().toIso8601String(),
      });
      await telemovel.sincronizar();
      expect(await telemovel.artigos.observarArtigos().first, isEmpty);
      expect(await itens(telemovel), isEmpty);
      expect(await telemovel.lojas.observarLojas().first, hasLength(1));
    });

    test('escrita lenta dentro da margem não se perde', () async {
      // Uma escrita com atualizado_em ligeiramente anterior ao último cursor
      // (transação longa) continua a ser apanhada graças à margem.
      final antes = servidor.tique().subtract(const Duration(minutes: 2));
      await telemovel.sincronizar();
      servidor.t('artigos').add({
        'id': 'artigo-lento',
        'nome': 'Lento',
        'categoria_id': null,
        'unidade': 'un',
        'ativo': true,
        'apagado_em': null,
        'atualizado_em': antes.toIso8601String(),
      });
      await telemovel.sincronizar();
      expect(
        (await telemovel.artigos.observarArtigos().first).map((a) => a.nome),
        contains('Lento'),
      );
    });
  });

  test('linhas antigas não voltam a ser puxadas a cada volta', () async {
    servidor.avancar(const Duration(hours: 1));
    await telemovel.sincronizar();
    final antes = servidor.linhasPuxadas;
    await telemovel.sincronizar();
    expect(servidor.linhasPuxadas, antes, reason: 'nada mudou no servidor');
  });

  group('conflitos e reativação', () {
    test('voltar a criar um artigo apagado reativa-o com o mesmo id', () async {
      await telemovel.artigos.eliminar(banana);
      await telemovel.sincronizar();
      final apagado = (await telemovel.artigos.apagados()).single;
      expect(apagado.id, banana);
      await telemovel.artigos.guardar(apagado, novo: true);
      await telemovel.sincronizar();
      final noServidor = servidor.t('artigos').where((a) => a['id'] == banana);
      expect(noServidor, hasLength(1));
      expect(noServidor.single['apagado_em'], isNull);
      expect(await telemovel.base.observarPendentes().first, isEmpty);
    });

    test('a última escrita a chegar ao servidor vence', () async {
      final noTelemovel = (await itens(telemovel)).single;
      servidor.online = false;
      await telemovel.lista.alterarQtd(noTelemovel, 3);
      servidor.online = true;

      final noPc = (await itens(pc)).single;
      await pc.lista.alterarQtd(noPc, 5);
      await pc.sincronizar();

      await telemovel.sincronizar();
      await pc.sincronizar();

      expect((await itens(telemovel)).single.qtd, 3);
      expect((await itens(pc)).single.qtd, 3);
      expect(servidor.t('itens_lista'), hasLength(1));
    });

    test('voltar a juntar um item apagado reativa-o (sem 23505)', () async {
      final item = (await itens(telemovel)).single;
      await telemovel.escrita.apagar('itens_lista', '$lidl|$leite');
      await telemovel.sincronizar();
      expect(await itens(telemovel), isEmpty);

      await telemovel.lista.incluir(lojaId: lidl, artigoId: leite);
      await telemovel.sincronizar();

      final fila = await telemovel.base.observarPendentes().first;
      expect(fila, isEmpty, reason: 'nenhum erro permanente');
      expect(servidor.t('itens_lista'), hasLength(1));
      final s = servidor.t('itens_lista').single;
      expect(s['apagado_em'], isNull);
      expect(s['id'], item.id, reason: 'mesma linha, reativada');
      expect((await itens(telemovel)).single.qtd, 2);
    });

    test('dois dispositivos sem rede juntam o mesmo artigo: uma só linha',
        () async {
      servidor.online = false;
      await telemovel.lista.incluir(lojaId: lidl, artigoId: banana, qtd: 1);
      await pc.lista.incluir(lojaId: lidl, artigoId: banana, qtd: 2);
      servidor.online = true;
      await telemovel.sincronizar();
      await pc.sincronizar();
      await telemovel.sincronizar();

      expect(
        servidor.t('itens_lista').where((i) => i['artigo_id'] == banana),
        hasLength(1),
      );
      expect(await telemovel.base.observarPendentes().first, isEmpty);
      expect(await pc.base.observarPendentes().first, isEmpty);
    });

    test('criar uma categoria com o nome de uma apagada reativa-a', () async {
      await telemovel.categorias.eliminar('cat-fruta');
      await telemovel.sincronizar();
      await telemovel.categorias.criar(nome: 'Fruta', ordem: 1);
      await telemovel.sincronizar();

      expect(await telemovel.base.observarPendentes().first, isEmpty);
      expect(servidor.t('categorias'), hasLength(1));
      expect(servidor.t('categorias').single['apagado_em'], isNull);
    });
  });

  group('concluir compra', () {
    CompraNova compra({String id = 'compra-1'}) => CompraNova(
      id: id,
      lojaId: lidl,
      local: 'Lidl Teste',
      data: DateTime(2026, 10, 15),
      linhas: const [
        LinhaNova(
          id: 'linha-1',
          precoId: 'preco-1',
          artigoId: leite,
          nome: 'Leite',
          unidade: Unidade.un,
          precoUnitCent: 89,
          quantidade: 2,
        ),
      ],
    );

    test('sem rede: fica na fila, limpa os comprados e é enviada depois',
        () async {
      final item = (await itens(telemovel)).single;
      await telemovel.lista.marcarComprado(item, comprado: true);
      await telemovel.sincronizar();

      servidor.online = false;
      await telemovel.compras.concluir(compra());
      final local = (await itens(telemovel)).single;
      expect(local.comprado, isFalse);

      // Dados antigos do servidor (comprado = true) não desfazem a compra.
      servidor.online = true;
      await telemovel.sync.puxar();
      expect((await itens(telemovel)).single.comprado, isFalse);

      await telemovel.sincronizar();
      expect(servidor.t('compras'), hasLength(1));
      expect(servidor.t('compras').single['total_cent'], 178);
      expect(servidor.t('itens_lista').single['comprado'], isFalse);
      final precos = await telemovel.artigos.observarPrecosAtuais().first;
      expect(precos.single.precoCent, 89);
    });

    test('repetir o pedido cria uma só compra (idempotente)', () async {
      await telemovel.compras.concluir(compra());
      servidor.perderRespostas = 1;
      await expectLater(telemovel.sync.enviar(), throwsA(isA<ErroSync>()));
      await telemovel.sync.enviar();
      expect(servidor.t('compras'), hasLength(1));
      expect(servidor.t('linhas_compra'), hasLength(1));
      expect(servidor.t('registos_preco'), hasLength(1));
    });
  });

  test('preferências sincronizam entre dispositivos', () async {
    final p = await telemovel.preferencias.observar().first;
    expect(p.direita.name, 'removerDaLista');
    await telemovel.preferencias.guardar(
      p.copyWith(lojaId: () => lidl),
    );
    await telemovel.sincronizar();
    await pc.sincronizar();
    expect((await pc.preferencias.observar().first).lojaId, lidl);
  });
}
