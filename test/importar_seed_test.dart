import 'dart:convert';
import 'dart:io';

import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/import/exportar.dart';
import 'package:cabaz_mensal/import/importar_seed.dart';
import 'package:cabaz_mensal/import/seed_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

String lerFixture() => File('test/fixtures/seed_mini.json').readAsStringSync();

/// Ids previsíveis: id-1, id-2, …
String Function() geradorIds() {
  var n = 0;
  return () => 'id-${++n}';
}

void main() {
  late SeedFicheiro seed;
  setUp(() => seed = SeedFicheiro.lerTexto(lerFixture()));

  group('leitura e validação', () {
    test('lê o seed sintético', () {
      expect(seed.lojas, hasLength(2));
      expect(seed.compras, hasLength(3));
      expect(seed.linhas, hasLength(5));
      expect(seed.linhas[2].pesoKg, 0.794);
      expect(seed.linhas[2].quantidade, isNull);
      expect(seed.listas.first.quantidadePadrao, 1.3);
      expect(seed.controlo!.totalCent, 553);
      expect(seed.controlo!.totalPorLojaCent, {'lidl': 180, 'pingo-doce': 373});
    });

    Map<String, dynamic> json() =>
        jsonDecode(lerFixture()) as Map<String, dynamic>;

    test('recusa referência a artigo inexistente', () {
      final j = json();
      (j['linhas'] as List).first['artigo_id'] = 999;
      expect(
        () => SeedFicheiro.lerTexto(jsonEncode(j)),
        throwsA(
          isA<SeedInvalido>().having(
            (e) => e.erros.join(),
            'erros',
            contains('"999"'),
          ),
        ),
      );
    });

    test('recusa cêntimos que não sejam inteiros', () {
      final j = json();
      (j['compras'] as List).first['total_cent'] = 0.3;
      expect(
        () => SeedFicheiro.lerTexto(jsonEncode(j)),
        throwsA(isA<SeedInvalido>()),
      );
    });

    test('recusa versão desconhecida e JSON inválido', () {
      final j = json()..['versao'] = 1;
      expect(
        () => SeedFicheiro.lerTexto(jsonEncode(j)),
        throwsA(isA<SeedInvalido>()),
      );
      expect(
        () => SeedFicheiro.lerTexto('{ruim'),
        throwsA(isA<SeedInvalido>()),
      );
    });

    test('recusa ids repetidos e unidade inválida', () {
      final j = json();
      final artigos = j['artigos'] as List;
      artigos[1]['id'] = 1;
      artigos[2]['unidade'] = 'lt';
      expect(
        () => SeedFicheiro.lerTexto(jsonEncode(j)),
        throwsA(
          isA<SeedInvalido>().having(
            (e) => e.erros.join('\n'),
            'erros',
            allOf(contains('Id repetido'), contains('unidade "lt"')),
          ),
        ),
      );
    });
  });

  group('payload da RPC', () {
    late PayloadImportacao p;
    setUp(() => p = montarPayload(seed, novoId: geradorIds()));

    test('contagens', () {
      expect(p.lojas, hasLength(2));
      expect(p.categorias, hasLength(2));
      expect(p.artigos, hasLength(5));
      expect(p.aliases, hasLength(3), reason: 'alias duplicado un/kg mantido');
      expect(p.compras, hasLength(3));
      expect(p.linhas, hasLength(5));
      expect(p.registosPreco, hasLength(6), reason: '5 linhas + 1 preço');
      expect(p.itensLista, hasLength(2));
      expect(p.totalCent, 553);
    });

    test('chaves estrangeiras resolvidas para os novos ids', () {
      final ids = {for (final a in p.artigos) a.id};
      final lojas = {for (final l in p.lojas) l.id};
      final compras = {for (final c in p.compras) c.id};
      expect(p.linhas.every((l) => ids.contains(l.artigoId)), isTrue);
      expect(p.linhas.every((l) => compras.contains(l.compraId)), isTrue);
      expect(p.compras.every((c) => lojas.contains(c.lojaId)), isTrue);
      expect(p.aliases.every((a) => lojas.contains(a.lojaId)), isTrue);
      final maca = p.artigos.firstWhere((a) => a.nome == 'Maçã Fuji');
      final frutas = p.categorias.firstWhere(
        (c) => c.nome == 'Frutas e legumes',
      );
      expect(maca.categoriaId, frutas.id);
      expect(maca.unidade, Unidade.kg);
    });

    test('lojas usam o slug do ficheiro', () {
      expect(p.lojas.map((l) => l.slug), ['lidl', 'pingo-doce']);
      expect(p.lojas.first.cadeia, 'Lidl');
    });

    test('pesos em gramas e preço unitário', () {
      final peso = p.linhas[2];
      expect(peso.pesoG, 794);
      expect(peso.quantidade, isNull);
      expect(peso.precoUnitCent, 219); // €/kg
      expect(p.linhas[3].precoUnitCent, 125); // 2,49 € / 2
    });

    test('registos de preço: um por linha (talao) + os do ficheiro', () {
      final talao = p.registosPreco.where((r) => r.origem == OrigemPreco.talao);
      expect(talao, hasLength(5));
      final lista = p.registosPreco.where((r) => r.origem == OrigemPreco.lista);
      expect(lista.single.precoCent, 25);
      // O registo do talão fica com a data e a loja da compra.
      final r = talao.elementAt(2);
      expect(dataIso(r.data), '2026-02-01');
      expect(r.lojaId, p.lojas[1].id);
    });

    test('poupança é a soma dos descontos', () {
      expect(p.compras.map((c) => c.poupancaCent), [0, 50, 0]);
    });

    test('compra a rever quando as linhas não batem com o total', () {
      expect(p.compras.map((c) => c.rever), [false, false, true]);
      expect(p.comprasRever, 1);
      expect(compraARever(totalCent: 30, somaLinhasCent: 10 + 20), isFalse);
    });

    test('JSON enviado à RPC', () {
      final j = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(
        j.keys,
        containsAll([
          'lojas',
          'categorias',
          'artigos',
          'aliases',
          'compras',
          'linhas_compra',
          'registos_preco',
          'itens_lista',
        ]),
      );
      final compra = (j['compras'] as List).first as Map;
      expect(compra['data'], '2026-01-10');
      expect(compra['total_cent'], 30);
      expect(compra['origem'], 'importacao');
      final linha = (j['linhas_compra'] as List)[2] as Map;
      expect(linha['peso_g'], 794);
      expect(linha.containsKey('peso_kg'), isFalse);
      final item = (j['itens_lista'] as List).first as Map;
      expect(item['qtd_padrao'], 1.3);
      // Nenhum valor monetário em double.
      for (final l in j['linhas_compra'] as List) {
        for (final k in ['bruto_cent', 'desconto_cent', 'pago_cent']) {
          expect((l as Map)[k], isA<int>());
        }
      }
    });

    test('UUIDs reais por omissão', () {
      final p2 = montarPayload(seed);
      expect(
        p2.lojas.first.id,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')),
      );
    });
  });

  group('importação com repositórios em memória', () {
    late BaseEmMemoria base;
    late FakeDadosRepository dados;
    late ImportadorSeed importador;

    setUp(() {
      base = BaseEmMemoria();
      dados = FakeDadosRepository(base);
      importador = ImportadorSeed(dados: dados);
    });

    test('totais de controlo batem: ✓ em todas as lojas', () async {
      final r = await importador.importar(seed, substituir: false);
      expect(r.contagens['compras'], 3);
      expect(r.contagens['artigos'], 5);
      expect(r.contagens['lojas'], 2);
      expect(r.totalCent, 553);
      expect(r.totalOk, isTrue);
      expect(r.comprasRever, 1);
      expect(
        {for (final l in r.lojas) l.slug: l.ok},
        {'lidl': true, 'pingo-doce': true},
      );
      expect(r.tudoOk, isTrue);
    });

    test('total de uma loja diferente do controlo: ✗ nessa loja', () async {
      final j = jsonDecode(lerFixture()) as Map<String, dynamic>;
      (j['controlo'] as Map)['total_por_loja_cent']['lidl'] = 181;
      final r = await importador.importar(
        SeedFicheiro.lerTexto(jsonEncode(j)),
        substituir: false,
      );
      final lidl = r.lojas.firstWhere((l) => l.slug == 'lidl');
      expect(lidl.ok, isFalse);
      expect(lidl.esperadoCent, 181);
      expect(r.lojas.firstWhere((l) => l.slug == 'pingo-doce').ok, isTrue);
      expect(r.tudoOk, isFalse);
    });

    test('loja do controlo que não chegou ao servidor aparece com ✗', () {
      final v = verificarControlo(
        const SeedControlo(
          contagens: {},
          totalCent: 100,
          totalPorLojaCent: {'mercadona': 100},
        ),
        const [],
      );
      expect(v.single.slug, 'mercadona');
      expect(v.single.ok, isFalse);
    });

    test('sem controlo no ficheiro, não marca ✓ nem ✗', () {
      final v = verificarControlo(null, const [
        ResumoLoja(
          lojaId: 'x',
          slug: 'lidl',
          nome: 'Lidl',
          nCompras: 1,
          totalCent: 5,
        ),
      ]);
      expect(v.single.ok, isNull);
    });

    test(
      'com dados existentes, só importa se substituir (sem duplicar)',
      () async {
        await importador.importar(seed, substituir: false);
        expect(await dados.temDados(), isTrue);
        expect(
          () => importador.importar(seed, substituir: false),
          throwsA(isA<ErroDados>()),
        );
        final r = await importador.importar(seed, substituir: true);
        expect(r.contagens['compras'], 3, reason: 'substitui, não duplica');
      },
    );

    test('exportar e voltar a importar dá os mesmos números', () async {
      await importador.importar(seed, substituir: false);
      // O servidor devolve as colunas; o payload em memória tem as mesmas.
      final exportado = exportacaoParaTexto(
        montarExportacao(await dados.lerTudo(), agora: DateTime(2026, 10, 15)),
      );
      final relido = SeedFicheiro.lerTexto(exportado);
      expect(relido.compras, hasLength(3));
      expect(relido.linhas, hasLength(5));
      expect(
        relido.precos,
        hasLength(1),
        reason: 'preços do talão são recriados',
      );
      expect(relido.controlo!.totalCent, 553);
      expect(relido.controlo!.totalPorLojaCent, {
        'lidl': 180,
        'pingo-doce': 373,
      });
      expect(relido.linhas[2].pesoKg, 0.794);

      final r = await importador.importar(relido, substituir: true);
      expect(r.tudoOk, isTrue);
      expect(r.contagens['registos_preco'], 6);
      expect(r.contagens['aliases'], 3);
    });
  });
}
