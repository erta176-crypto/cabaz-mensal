import 'dart:convert';
import 'dart:io';

import 'package:cabaz_mensal/domain/dinheiro.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/export/dados_export.dart';
import 'package:cabaz_mensal/export/escrever_pdf.dart';
import 'package:cabaz_mensal/export/tabela_export.dart';
import 'package:cabaz_mensal/export/texto_lista.dart';
import 'package:cabaz_mensal/import/analisar_artigos.dart';
import 'package:cabaz_mensal/import/analisar_compras.dart';
import 'package:cabaz_mensal/import/analisar_lista.dart';
import 'package:cabaz_mensal/import/campos.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/tabela_lida.dart';
import 'package:cabaz_mensal/import/valores.dart';
import 'package:flutter_test/flutter_test.dart';

const lidl = Loja(id: 'l1', slug: 'lidl', nome: 'Lidl');
const pingo = Loja(id: 'l2', slug: 'pingo-doce', nome: 'Pingo Doce');
const fruta = Categoria(id: 'c1', nome: 'Fruta', ordem: 1);
const mercearia = Categoria(id: 'c2', nome: 'Mercearia', ordem: 2);
const banana = Artigo(id: 'a1', nome: 'Banana', categoriaId: 'c1', unidade: Unidade.kg);
const leite = Artigo(id: 'a2', nome: 'Leite Meio Gordo', categoriaId: 'c2', unidade: Unidade.un);
final d = DateTime(2026);

Catalogo catalogo({
  List<Artigo> apagados = const [],
  List<ItemLista> itens = const [
    ItemLista(id: 'i1', lojaId: 'l1', artigoId: 'a2', qtdPadrao: 2, incluido: true),
  ],
}) => Catalogo(
  lojas: const [lidl, pingo],
  categorias: const [fruta, mercearia],
  artigos: const [banana, leite],
  artigosApagados: apagados,
  aliases: const {
    'a2': ['LEITE MG PÇ'],
  },
  precos: [
    PrecoAtual(artigoId: 'a1', lojaId: 'l1', precoCent: 119, data: d),
    PrecoAtual(artigoId: 'a2', lojaId: 'l1', precoCent: 75, data: d),
  ],
  itens: itens,
);

TabelaLida csv(String texto) => lerCsv(utf8.encode(texto));

Previsualizacao artigos(TabelaLida t, {Catalogo? cat, bool atualizar = true}) =>
    analisarArtigos(
      t,
      adivinharColunas(t.cabecalhos, TipoImportacao.artigos),
      cat ?? catalogo(),
      atualizarExistentes: atualizar,
      hoje: DateTime(2026, 10, 18),
    );

List<EstadoLinha> estados(Previsualizacao p) => [for (final l in p.linhas) l.estado];

void main() {
  group('leitura', () {
    test('CSV com ; e vírgula decimal, BOM e aspas', () {
      final t = csv('﻿Artigo;Preço\n"Pão; caseiro";1,29\n');
      expect(t.cabecalhos, ['Artigo', 'Preço']);
      expect(t.linhas.single, ['Pão; caseiro', '1,29']);
    });

    test('CSV com ,', () {
      final t = csv('Artigo,Preço\nBanana,"1,19"\r\nLeite,0.75\n');
      expect(t.linhas, [
        ['Banana', '1,19'],
        ['Leite', '0.75'],
      ]);
    });

    test('XLSX: cabeçalhos em português, números e datas', () {
      final bytes = escreverXlsx([
        TabelaExport('Folha', const ['Data', 'Preço', 'Qtd'], [
          [DateTime(2026, 3, 5), const Cent(129), 2],
        ]),
      ]);
      final t = lerXlsx(bytes);
      expect(t.cabecalhos, ['Data', 'Preço', 'Qtd']);
      expect(t.linhas.single, ['2026-03-05', '1.29', '2']);
      expect(lerData(t.linhas.single[0]), DateTime(2026, 3, 5));
      expect(centDeTexto(t.linhas.single[1]), 129);
    });

    test('datas nos dois formatos e data inválida', () {
      expect(lerData('05/03/2026'), DateTime(2026, 3, 5));
      expect(lerData('2026-03-05'), DateTime(2026, 3, 5));
      expect(lerData('31/02/2026'), isNull);
      expect(lerData('ontem'), isNull);
    });

    test('cêntimos', () {
      expect(centDeTexto('1,29'), 129);
      expect(centDeTexto('1.29'), 129);
      expect(eurosParaCent(0.1 + 0.2), 30);
      expect(centDeTexto('0,1')! + centDeTexto('0,2')!, 30);
    });

    test('quantidade em texto livre', () {
      expect(lerQuantidadeTexto('1,5 kg'), (valor: 1.5, unidade: 'kg'));
      expect(lerQuantidadeTexto('2'), (valor: 2, unidade: null));
      expect(lerQuantidadeTexto('2 pacotes'), (valor: 2, unidade: 'pacotes'));
      expect(lerQuantidadeTexto('q.b.').valor, isNull);
    });
  });

  test('adivinhar colunas pelo cabeçalho', () {
    expect(
      adivinharColunas(['PVP', 'Secção', 'Produto', 'xyz'], TipoImportacao.artigos),
      [Campo.preco, Campo.categoria, Campo.artigo, Campo.ignorar],
    );
    expect(adivinharCampo('Preço', TipoImportacao.compras), Campo.precoUnit);
    expect(adivinharCampo('Total da compra', TipoImportacao.compras), Campo.totalCompra);
  });

  group('artigos e preços', () {
    test('novo, atualiza, já existe e erros', () {
      final p = artigos(csv(
        'Artigo;Categoria;Unidade;Loja;Preço\n'
        'Banana;Fruta;kg;Lidl;1,19\n' // igual
        'Leite meio gordo;Mercearia;un;Lidl;0,79\n' // preço mudou
        'Kiwi;Fruta;kg;Lidl;3,49\n' // novo
        ';Fruta;kg;Lidl;1\n' // artigo vazio
        'Pera;Fruta;kg;Lidl;abc\n', // preço inválido
      ));
      expect(estados(p), [
        EstadoLinha.jaExiste,
        EstadoLinha.atualiza,
        EstadoLinha.novo,
        EstadoLinha.erro,
        EstadoLinha.erro,
      ]);
      expect(p.linhas[3].motivo, 'Artigo vazio');
      expect(p.linhas[4].motivo, contains('Preço inválido'));
      expect(p.resumo, '5 linhas: 1 novas, 1 atualizam, 1 já existem, 2 com erro');
      expect(p.aImportar, 2);
      expect(p.lote.precos.map((x) => x['preco_cent']), [79, 349]);
      expect(p.lote.precos.every((x) => x['origem'] == 'manual'), isTrue);
    });

    test('"Manter o que existe" não altera', () {
      final p = artigos(
        csv('Artigo;Loja;Preço\nBanana;Lidl;9,99\n'),
        atualizar: false,
      );
      expect(p.linhas.single.estado, EstadoLinha.jaExiste);
      expect(p.lote.vazio, isTrue);
    });

    test('encontra pelo alias, sem acentos nem maiúsculas', () {
      final p = artigos(csv('Artigo;Loja;Preço\nleite mg pc;Lidl;0,75\n'));
      expect(p.linhas.single.estado, EstadoLinha.jaExiste);
    });

    test('categoria nova é criada', () {
      final p = artigos(csv('Artigo;Categoria\nSabão;Limpeza\n'));
      expect(p.lote.categorias.values.single['nome'], 'Limpeza');
      expect(p.lote.artigos.values.single['categoria_id'],
          p.lote.categorias.keys.single);
    });

    test('artigo apagado volta com o mesmo id', () {
      const kiwi = Artigo(id: 'a9', nome: 'Kiwi', categoriaId: null, unidade: Unidade.kg);
      final p = artigos(
        csv('Artigo;Loja;Preço\nKIWI;Lidl;3,49\n'),
        cat: catalogo(apagados: [kiwi]),
      );
      expect(p.linhas.single.estado, EstadoLinha.novo);
      expect(p.lote.artigos.keys.single, 'a9');
    });
  });

  group('compras', () {
    // Dois talões no mesmo dia e local, com totais diferentes (como no seed).
    final existentes = [
      CompraExistente(lojaId: 'l1', data: DateTime(2026, 2, 1), local: 'Lidl X', totalCent: 300),
      CompraExistente(lojaId: 'l1', data: DateTime(2026, 2, 1), local: 'Lidl X', totalCent: 120),
    ];

    Previsualizacao compras(String texto) {
      final t = csv(texto);
      return analisarCompras(
        t,
        adivinharColunas(t.cabecalhos, TipoImportacao.compras),
        catalogo(),
        existentes,
      );
    }

    test('com "Total da compra": dois talões separados, ambos "Já existe"', () {
      final p = compras(
        'Data;Loja;Local;Artigo;Pago;Total da compra\n'
        '01/02/2026;Lidl;Lidl X;Banana;1,00;3,00\n'
        '01/02/2026;Lidl;Lidl X;Leite meio gordo;2,00;3,00\n'
        '01/02/2026;Lidl;Lidl X;Banana;1,20;1,20\n',
      );
      expect(estados(p), List.filled(3, EstadoLinha.jaExiste));
      expect(p.lote.compras, isEmpty);
      expect(p.linhas.every((l) => l.aviso == null), isTrue);
    });

    test('sem "Compra" nem total: aviso de possíveis talões juntos', () {
      final p = compras(
        'Data;Loja;Local;Artigo;Pago\n'
        '01/02/2026;Lidl;Lidl X;Banana;1,00\n'
        '01/02/2026;Lidl;Lidl X;Banana;1,20\n',
      );
      expect(p.linhas.first.aviso, avisoTaloesJuntos);
      expect(p.lote.compras, hasLength(1));
    });

    test('compra nova: total, rever e preço por linha', () {
      final p = compras(
        'Data;Loja;Artigo;Quantidade;Preço unitário;Total da compra\n'
        '2026-03-10;Pingo Doce;Leite meio gordo;2;0,79;1,60\n'
        '2026-03-10;Pingo Doce;Kiwi;;;\n', // falta o valor pago
      );
      expect(estados(p), [EstadoLinha.novo, EstadoLinha.erro]);
      final c = p.lote.compras.single;
      expect(c['total_cent'], 160);
      expect(c['rever'], isTrue); // 158 ≠ 160
      expect(p.lote.linhas.single['pago_cent'], 158);
      expect(p.lote.precos.single['origem'], 'talao');
    });
  });

  group('ida e volta (exportar → importar = zero alterações)', () {
    final cat = catalogo();
    List<TabelaLida> emCsvEXlsx(TabelaExport t) => [
      lerCsv(escreverCsv(t)),
      lerXlsx(escreverXlsx([t])),
    ];

    test('artigos e preços, e o portão (2 atualiza, 1 novo)', () {
      final t = tabelaArtigos(
        artigos: cat.artigos,
        categorias: cat.categorias,
        lojas: cat.lojas,
        precos: cat.precos,
      );
      for (final lida in emCsvEXlsx(t)) {
        expect(estados(artigos(lida)), everyElement(EstadoLinha.jaExiste));
      }
      // Excel editado: 2 preços mudados e 1 artigo novo.
      final editada = TabelaExport(t.nome, t.cabecalhos, [
        for (final l in t.linhas) [...l.take(4), const Cent(1)],
        ['Kiwi', 'Fruta', 'kg', 'Lidl', const Cent(349)],
      ]);
      final p = artigos(lerXlsx(escreverXlsx([editada])));
      expect(p.contar(EstadoLinha.atualiza), 2);
      expect(p.contar(EstadoLinha.novo), 1);
    });

    test('compras e linhas', () {
      final tabelas = {
        'lojas': [lidl.toMap()],
        'artigos': [banana.toMap()],
        'compras': [
          for (final (id, total) in [('x1', 300), ('x2', 120)])
            {
              'id': id,
              'loja_id': 'l1',
              'local': 'Lidl X',
              'data': '2026-02-01',
              'total_cent': total,
              'poupanca_cent': 0,
              'rever': false,
            },
        ],
        'linhas_compra': [
          for (final (c, pago) in [('x1', 300), ('x2', 120)])
            {
              'id': 'l$c',
              'compra_id': c,
              'artigo_id': 'a1',
              'texto_original': 'BANANA',
              'quantidade': null,
              'peso_g': 794,
              'preco_unit_cent': 378,
              'bruto_cent': pago,
              'desconto_cent': 0,
              'pago_cent': pago,
            },
        ],
      };
      final linhas = tabelasCompras(tabelas).first;
      final existentes = [
        for (final c in tabelas['compras']!)
          CompraExistente(
            lojaId: 'l1',
            data: DateTime(2026, 2, 1),
            local: 'Lidl X',
            totalCent: c['total_cent'] as int,
          ),
      ];
      for (final lida in emCsvEXlsx(linhas)) {
        final p = analisarCompras(
          lida,
          adivinharColunas(lida.cabecalhos, TipoImportacao.compras),
          cat,
          existentes,
        );
        expect(estados(p), everyElement(EstadoLinha.jaExiste));
      }
    });

    test('lista do mês', () {
      final cat2 = catalogo(itens: const [
        ItemLista(id: 'i1', lojaId: 'l1', artigoId: 'a1', qtdPadrao: 1.3, incluido: true),
        ItemLista(id: 'i2', lojaId: 'l2', artigoId: 'a2', qtdPadrao: 2, incluido: true, comprado: true),
      ]);
      final t = tabelaLista(
        itens: cat2.itens,
        artigos: cat2.artigos,
        categorias: cat2.categorias,
        lojas: cat2.lojas,
      );
      for (final lida in emCsvEXlsx(t)) {
        final p = analisarLista(
          lida,
          adivinharColunas(lida.cabecalhos, TipoImportacao.lista),
          cat2,
        );
        expect(estados(p), everyElement(EstadoLinha.jaExiste));
      }
    });
  });

  group('lista: CSV da app antiga', () {
    const texto =
        '﻿Categoria;Artigo;Comprado;Quantidade;Supermercado\n'
        'Fruta;Banana;Sim;1,5 kg;Lidl\n'
        'Fruta;Maçã;Não;;Lidl\n' // catálogo
        'Mercearia;Arroz;Não;2 pacotes;\n'; // sem supermercado

    test('reconhecida pelo cabeçalho, quantidades e comprado', () {
      final t = csv(texto);
      expect(eFormatoAppAntiga(t.cabecalhos), isTrue);
      final p = analisarLista(
        t,
        adivinharColunas(t.cabecalhos, TipoImportacao.lista),
        catalogo(),
        lojaPorOmissao: pingo,
      );
      expect(estados(p), [EstadoLinha.novo, EstadoLinha.ignorada, EstadoLinha.novo]);
      expect(p.linhas[1].motivo, motivoSemQuantidade);
      final banana = p.lote.itens['l1|a1']!;
      expect(banana['qtd'], 1.5);
      expect(banana['comprado'], isTrue);
      expect(p.lote.itens.keys.where((k) => k.startsWith('l2|')), hasLength(1));
    });

    test('sem loja por omissão: erro; com a opção, artigos sem quantidade entram no catálogo', () {
      final t = csv(texto);
      final p = analisarLista(
        t,
        adivinharColunas(t.cabecalhos, TipoImportacao.lista),
        catalogo(),
        incluirSemQuantidade: true,
      );
      expect(estados(p), [EstadoLinha.novo, EstadoLinha.novo, EstadoLinha.erro]);
      // A linha do Arroz está em erro (sem loja), por isso só a Maçã é criada.
      expect(p.lote.artigos.values.map((a) => a['nome']), ['Maçã']);
    });
  });

  group('TXT e PDF da lista', () {
    test('emoji por categoria (🛍️ sem correspondência)', () {
      expect(emojiCategoria('Lacticínios e ovos'), '🥛');
      expect(emojiCategoria('Frutas e legumes'), '🍎');
      expect(emojiCategoria('Mercearia vegetariana'), '🌱');
      expect(emojiCategoria('Carne e charcutaria'), '🍗');
      expect(emojiCategoria('Animais de estimação'), '🐾');
      expect(emojiCategoria('Bebidas e infusões'), '🧃');
      expect(emojiCategoria('Ferramentas'), '🛍️');
    });

    test('texto pronto para o WhatsApp', () {
      final linhas = [
        const LinhaParaTexto(loja: 'Lidl', categoria: fruta, artigo: 'Banana', quantidade: '2 kg'),
        const LinhaParaTexto(loja: 'Lidl', categoria: null, artigo: 'Pilhas', quantidade: '1 un'),
      ];
      expect(
        textoLista(linhas, loja: 'Lidl', data: DateTime(2026, 10, 18)),
        '🛒 Lista de compras · Lidl · 18/10/2026\n\n'
        '🍎 Fruta\n• Banana — 2 kg\n\n'
        '🛍️ Sem categoria\n• Pilhas — 1 un',
      );
      expect(textoLista(linhas, data: DateTime(2026, 10, 18)), contains('• Banana — 2 kg (Lidl)'));
    });

    test('PDF gerado com € e acentos', () async {
      final letra = await File('assets/fonts/InstrumentSans.ttf').readAsBytes();
      final lista = await pdfLista(
        titulo: '🛒 Lista de compras · Lidl · 18/10/2026',
        blocos: const [BlocoLista('🍎 Fruta', ['• Maçã — 1,5 kg'])],
        letra: letra,
      );
      final precos = await pdfTabela(
        titulo: 'Preços',
        tabela: TabelaExport('Preços', const ['Artigo', 'Lidl'], [
          ['Pão de forma', const Cent(129)],
        ]),
        letra: letra,
      );
      for (final pdf in [lista, precos]) {
        expect(ascii.decode(pdf.sublist(0, 4)), '%PDF');
      }
    });
  });
}
