import 'dart:convert';
import 'dart:io';

import 'package:cabaz_mensal/data/local/base_local.dart';
import 'package:cabaz_mensal/data/local/repositorios_locais.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/data/supabase/supabase_estatisticas.dart';
import 'package:cabaz_mensal/data/sync/escrita.dart';
import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = {
  'total_cent': 5000,
  'n_compras': 2,
  'poupanca_cent': 100,
  'por_mes': [
    {'mes': '2026-10', 'total_cent': 5000, 'n_compras': 2},
  ],
  'por_loja': <Object>[],
  'por_categoria': <Object>[],
  'artigos': <Object>[],
};

const _filtro = (periodo: Periodo.esteMes, lojaId: null);

void main() {
  late BaseLocal base;
  late List<(String, Map<String, dynamic>)> chamadas;
  late Future<dynamic> Function(String, Map<String, dynamic>) comRede;
  late SupabaseEstatisticasRepository repo;

  setUp(() {
    base = BaseLocal(NativeDatabase.memory());
    chamadas = [];
    comRede = (nome, params) async {
      chamadas.add((nome, params));
      return nome == 'painel' ? _json : <Object>[];
    };
    repo = SupabaseEstatisticasRepository(
      rpc: (n, p) => comRede(n, p),
      lerLinhas: (_) async => const [],
      base: base,
    );
  });

  tearDown(() => base.close());

  group('painel', () {
    test('com rede: devolve os dados e grava a cache', () async {
      final r = await repo.painel(_filtro, hoje: DateTime(2026, 10, 25));
      expect(r.guardadoEm, isNull);
      expect(r.dados.totalCent, 5000);
      expect(chamadas.single.$1, 'painel');
      expect(chamadas.single.$2, {
        'p_de': '2026-10-01',
        'p_ate': '2026-10-25',
        'p_loja': null,
      });
      final guardado = jsonDecode(
        (await base.lerEstado('painel:esteMes:todas'))!,
      );
      expect(guardado['de'], '2026-10-01');
      expect(guardado['ate'], '2026-10-25');
      expect(guardado['dados'], _json);
    });

    test('a chave da cache inclui a loja', () async {
      await repo.painel((
        periodo: Periodo.esteAno,
        lojaId: 'l1',
      ), hoje: DateTime(2026, 10, 25));
      expect(await base.lerEstado('painel:esteAno:l1'), isNotNull);
      expect(chamadas.single.$2['p_loja'], 'l1');
    });

    test('sem rede com cache do mesmo intervalo: devolve a cache', () async {
      await repo.painel(_filtro, hoje: DateTime(2026, 10, 25));
      comRede = (_, _) async => throw const SocketException('sem rede');
      final r = await repo.painel(_filtro, hoje: DateTime(2026, 10, 25));
      expect(r.guardadoEm, isNotNull);
      expect(r.dados.totalCent, 5000);
    });

    test('sem rede com cache de outro intervalo: ErroDados', () async {
      await repo.painel(_filtro, hoje: DateTime(2026, 10, 25));
      comRede = (_, _) async => throw const SocketException('sem rede');
      expect(
        repo.painel(_filtro, hoje: DateTime(2026, 11, 3)),
        throwsA(isA<ErroDados>()),
      );
    });

    test('sem rede e sem cache: ErroDados', () async {
      comRede = (_, _) async => throw const SocketException('sem rede');
      expect(
        repo.painel(_filtro, hoje: DateTime(2026, 10, 25)),
        throwsA(
          isA<ErroDados>().having(
            (e) => e.mensagem,
            'mensagem',
            'Sem rede e sem dados guardados para este filtro.',
          ),
        ),
      );
    });

    test('um ErroDados do servidor é relançado mesmo havendo cache', () async {
      await repo.painel(_filtro, hoje: DateTime(2026, 10, 25));
      comRede = (_, _) async => throw const ErroDados('Erro SQL');
      expect(
        repo.painel(_filtro, hoje: DateTime(2026, 10, 25)),
        throwsA(
          isA<ErroDados>().having((e) => e.mensagem, 'mensagem', 'Erro SQL'),
        ),
      );
    });
  });

  group('compras', () {
    test('pesquisa vazia envia p_artigos e p_texto a null', () async {
      await repo.compras(
        _filtro,
        artigoIds: const [],
        texto: '',
        hoje: DateTime(2026, 10, 25),
      );
      expect(chamadas.single.$1, 'historico_compras');
      expect(chamadas.single.$2, {
        'p_de': '2026-10-01',
        'p_ate': '2026-10-25',
        'p_loja': null,
        'p_artigos': null,
        'p_texto': null,
      });
    });

    test('com pesquisa envia as listas e o texto', () async {
      await repo.compras(
        (periodo: Periodo.tudo, lojaId: 'l2'),
        artigoIds: const ['a1', 'a2'],
        texto: 'leite',
        hoje: DateTime(2026, 10, 25),
      );
      final p = chamadas.single.$2;
      expect(p['p_de'], '2000-01-01');
      expect(p['p_loja'], 'l2');
      expect(p['p_artigos'], ['a1', 'a2']);
      expect(p['p_texto'], 'leite');
    });

    test('lê as compras devolvidas', () async {
      comRede = (_, _) async => [
        {
          'id': 'c1',
          'loja_id': 'l1',
          'data': '2026-10-20',
          'local': null,
          'total_cent': 1234,
          'poupanca_cent': 0,
          'origem': 'manual',
          'rever': false,
          'n_linhas': 3,
        },
      ];
      final r = await repo.compras(_filtro, hoje: DateTime(2026, 10, 25));
      expect(r.single.totalCent, 1234);
      expect(r.single.data, DateTime(2026, 10, 20));
    });

    test('sem rede: ErroDados com a mensagem do histórico', () async {
      comRede = (_, _) async => throw const SocketException('sem rede');
      expect(
        repo.compras(_filtro, hoje: DateTime(2026, 10, 25)),
        throwsA(
          isA<ErroDados>().having(
            (e) => e.mensagem,
            'mensagem',
            'Sem rede: o histórico precisa do servidor.',
          ),
        ),
      );
    });
  });

  group('linhas', () {
    test('lê as linhas da compra', () async {
      final r = SupabaseEstatisticasRepository(
        rpc: (_, _) async => null,
        lerLinhas: (id) async => [
          {
            'id': 'x1',
            'compra_id': id,
            'artigo_id': null,
            'texto_original': 'LEITE',
            'quantidade': 2,
            'peso_g': null,
            'preco_unit_cent': 80,
            'bruto_cent': 160,
            'desconto_cent': 0,
            'pago_cent': 160,
          },
        ],
        base: base,
      );
      final l = await r.linhas('c1');
      expect(l.single.compraId, 'c1');
      expect(l.single.pagoCent, 160);
    });

    test('sem rede: ErroDados com a mensagem do histórico', () async {
      final r = SupabaseEstatisticasRepository(
        rpc: (_, _) async => null,
        lerLinhas: (_) async => throw const SocketException('sem rede'),
        base: base,
      );
      expect(r.linhas('c1'), throwsA(isA<ErroDados>()));
    });
  });

  test('observarRegistos: só do artigo, sem apagados, por data', () async {
    final escrita = Escrita(base);
    Future<void> preco(String id, String artigo, String data, int cent) =>
        escrita.inserir('registos_preco', {
          'id': id,
          'artigo_id': artigo,
          'loja_id': 'l1',
          'data': data,
          'preco_cent': cent,
          'origem': 'manual',
          'criado_em': '2026-10-25T10:00:0$cent',
        });
    await preco('r3', 'a1', '2026-10-20', 3);
    await preco('r1', 'a1', '2026-09-01', 1);
    await preco('r2', 'a1', '2026-10-20', 2);
    await preco('r4', 'a2', '2026-10-01', 4);
    await preco('r5', 'a1', '2026-10-05', 5);
    await escrita.apagar('registos_preco', 'r5');

    final r = await LocalArtigosRepository(
      base,
      escrita,
    ).observarRegistos('a1').first;
    expect(r.map((x) => x.id), ['r1', 'r2', 'r3']);
  });

  test('limparCache apaga painel:% e cursor:% e mantém o resto', () async {
    await base.gravarEstado('painel:esteMes:todas', '{}');
    await base.gravarEstado('painel:tudo:l1', '{}');
    await base.gravarEstado('cursor:lojas', '2026-10-01');
    await base.gravarEstado('reiniciado_em', 'x');
    await base.limparCache();
    expect(await base.lerEstado('painel:esteMes:todas'), isNull);
    expect(await base.lerEstado('painel:tudo:l1'), isNull);
    expect(await base.lerEstado('cursor:lojas'), isNull);
    expect(await base.lerEstado('reiniciado_em'), 'x');
  });
}
