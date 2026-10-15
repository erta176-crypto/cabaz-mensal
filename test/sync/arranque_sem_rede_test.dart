import 'dart:async';
import 'dart:io';

import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/local/repositorios_locais.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/data/sync/escrita.dart';
import 'package:cabaz_mensal/data/sync/sincronizador.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'servidor_falso.dart';
import 'sincronizacao_test.dart' show semear, lidl, leite;

/// Reproduz o portão da 1A com o caminho real (iniciar, temporizadores,
/// rede): alterações sem rede, fechar e reabrir a app sem rede, ligar a rede.
void main() {
  test('alterações feitas sem rede são enviadas quando a rede volta, '
      'mesmo depois de reabrir a app', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final pasta = await Directory.systemTemp.createTemp('cabaz');
    final ficheiro = File('${pasta.path}/base.sqlite');
    final servidor = ServidorFalso();
    semear(servidor);

    // 1. Primeira abertura, com rede.
    var rede = StreamController<bool>.broadcast();
    var base = BaseLocal(NativeDatabase(ficheiro));
    var sync = Sincronizador(
      base: base,
      servidor: servidor,
      utilizadorId: 'u1',
      rede: rede.stream,
      periodo: const Duration(milliseconds: 200),
    );
    await sync.iniciar();
    expect(sync.estadoAtual.online, isTrue);

    // 2. Modo de avião: alterações ficam na fila.
    servidor.online = false;
    rede.add(false);
    final escrita = Escrita(base)..aposEscrever = sync.sincronizar;
    final lista = LocalListaRepository(base, escrita);
    final item = (await lista.observarItens().first).single;
    await lista.marcarComprado(item, comprado: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sync.estadoAtual.online, isFalse);
    expect(sync.estadoAtual.pendentes, 1);

    // 3. Fechar a app e voltar a abrir, ainda sem rede.
    await sync.fechar();
    await base.close();
    await rede.close();
    rede = StreamController<bool>.broadcast();
    base = BaseLocal(NativeDatabase(ficheiro));
    sync = Sincronizador(
      base: base,
      servidor: servidor,
      utilizadorId: 'u1',
      rede: rede.stream,
      periodo: const Duration(milliseconds: 200),
    );
    await sync.iniciar();
    expect(sync.estadoAtual.pendentes, 1);
    expect(sync.estadoAtual.online, isFalse);

    // 4. A rede volta.
    servidor.online = true;
    rede.add(true);
    final fim = DateTime.now().add(const Duration(seconds: 5));
    while (sync.estadoAtual.pendentes > 0 && DateTime.now().isBefore(fim)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(sync.estadoAtual.pendentes, 0);
    expect(sync.estadoAtual.online, isTrue);
    expect(sync.estadoAtual.ultimoErro, isNull);
    final noServidor = servidor.t('itens_lista').single;
    expect(noServidor['artigo_id'], leite);
    expect(noServidor['loja_id'], lidl);
    expect(noServidor['comprado'], isTrue);

    await sync.fechar();
    await base.close();
    await pasta.delete(recursive: true);
  });

  test('o estado reflete os pendentes logo ao arrancar', () async {
    final base = BaseLocal(NativeDatabase.memory());
    final sync = Sincronizador(
      base: base,
      servidor: ServidorFalso()..online = false,
      utilizadorId: 'u1',
    );
    await base.gravarEstado('utilizador', 'u1');
    await base.enfileirar(
      operacao: 'atualizar',
      alvo: 'itens_lista',
      chaves: const ['itens_lista:a|b'],
      payload: const {
        'filtro': {'loja_id': 'a', 'artigo_id': 'b'},
        'campos': {'comprado': true},
      },
    );
    await sync.iniciar();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sync.estadoAtual, isA<EstadoSync>());
    expect(sync.estadoAtual.pendentes, 1);
    await sync.fechar();
    await base.close();
  });
}
