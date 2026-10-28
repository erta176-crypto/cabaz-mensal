import 'dart:io';

import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/taloes/importar_taloes.dart';
import 'package:flutter_test/flutter_test.dart';

String _f(String nome) =>
    File('test/fixtures/taloes/$nome.txt')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

const _pd = Loja(id: 'pd', slug: 'pingo-doce', nome: 'Pingo Doce');
const _lidl = Loja(id: 'lidl', slug: 'lidl', nome: 'Lidl');
const _bife = Artigo(
  id: 'a-bife',
  nome: 'Bife de frango',
  categoriaId: null,
  unidade: Unidade.kg,
);
const _gelado = Artigo(
  id: 'a-gelado',
  nome: 'Gelado de coco',
  categoriaId: null,
  unidade: Unidade.un,
);

Catalogo _cat() => Catalogo(
  lojas: const [_pd, _lidl],
  categorias: const [
    Categoria(id: 'c-peixe', nome: 'Peixe', ordem: 1),
    Categoria(id: 'c-fruta', nome: 'Frutas e legumes', ordem: 2),
  ],
  artigos: const [_bife, _gelado],
  aliases: const {
    'a-gelado': ['GELADO DOUBLE COCO'],
  },
);

var _n = 0;
String _id() => 'id${_n++}';

void main() {
  setUp(() => _n = 0);

  ({List<TalaoAnalisado> taloes, List<NaoReconhecido> naoReconhecidos})
  analisar(
    List<(String, String)> lidos, {
    List<CompraExistente> existentes = const [],
  }) => analisarTaloes(
    [for (final (f, t) in lidos) (ficheiro: f, texto: t)],
    _cat(),
    existentes,
  );

  group('repartirDesconto', () {
    test('proporcional e com a soma exata', () {
      expect(repartirDesconto([300, 100], 100), [75, 25]);
      final r = repartirDesconto([100, 100, 100], 100);
      expect(r.fold(0, (a, b) => a + b), 100);
      expect(r, [34, 33, 33]); // o cêntimo a mais vai para a primeira maior
    });

    test('o resto vai para as linhas de maior valor', () {
      expect(repartirDesconto([10, 1000], 3), [0, 3]);
    });

    test('nenhuma linha fica com desconto maior do que o valor', () {
      final r = repartirDesconto([50, 50], 200);
      expect(r, [50, 50]);
    });

    test('sem desconto ou sem linhas', () {
      expect(repartirDesconto([100, 200], 0), [0, 0]);
      expect(repartirDesconto(const [], 50), isEmpty);
    });
  });

  group('analisarTaloes', () {
    test('dois talões novos com loja, linhas e artigos', () {
      final r = analisar([
        ('pd.pdf', _f('pingo_doce')),
        ('lidl.pdf', _f('lidl')),
      ]);
      expect(r.naoReconhecidos, isEmpty);
      expect(r.taloes.map((t) => t.estado), [
        EstadoTalao.novo,
        EstadoTalao.novo,
      ]);
      expect(r.taloes[0].loja.id, 'pd');

      final lidl = r.taloes[1];
      final bife = lidl.linhas.firstWhere(
        (l) => l.linha.texto == 'BIFE DE FRANGO',
      );
      expect(bife.artigo?.id, 'a-bife'); // pelo nome normalizado
      final gelado = lidl.linhas.firstWhere(
        (l) => l.linha.texto == 'GELADO DOUBLE COCO',
      );
      expect(gelado.artigo?.id, 'a-gelado'); // pelo alias
      final salada = lidl.linhas.firstWhere(
        (l) => l.linha.texto == 'SALADA COM COENTROS',
      );
      expect(salada.artigo, isNull);
      expect(salada.nomeNovo, 'Salada com coentros');
    });

    test('desconto da compra repartido pelas linhas (Saldo Pingo Doce)', () {
      final pd = analisar([('pd.pdf', _f('pingo_doce'))]).taloes.single;
      final descontos = pd.linhas.fold(0, (s, l) => s + l.descontoTotalCent);
      // próprios 32 + 20 + 5 e o saldo de 200
      expect(descontos, 257);
      final pago = pd.linhas.fold(
        0,
        (s, l) => s + l.linha.brutoCent - l.descontoTotalCent,
      );
      expect(pago, pd.talao.totalCent);
    });

    test('igual a uma compra já gravada → jaExiste', () {
      final r = analisar(
        [('lidl.pdf', _f('lidl'))],
        existentes: [
          CompraExistente(
            lojaId: 'lidl',
            data: DateTime(2026, 10, 4),
            local: null,
            totalCent: 1477,
          ),
        ],
      );
      expect(r.taloes.single.estado, EstadoTalao.jaExiste);
    });

    test('duas cópias do mesmo talão → a segunda é repetidoNoLote', () {
      final r = analisar([('a.pdf', _f('lidl')), ('a (1).pdf', _f('lidl'))]);
      expect(r.taloes.map((t) => t.estado), [
        EstadoTalao.novo,
        EstadoTalao.repetidoNoLote,
      ]);
    });

    test('soma que não bate → aRever', () {
      final r = analisar([
        ('lidl.pdf', _f('lidl').replaceFirst('Total 14,77', 'Total 14,99')),
      ]);
      expect(r.taloes.single.estado, EstadoTalao.aRever);
    });

    test('loja que não está no catálogo e texto desconhecido', () {
      final r = analisar([
        ('lec.pdf', _f('leclerc')),
        ('x.pdf', 'CONTINENTE\nTOTAL 1,00'),
        ('y.pdf', _f('lidl').replaceFirst('Data de Venda: 2026-10-04', '')),
      ]);
      expect(r.taloes, isEmpty);
      expect(r.naoReconhecidos.map((n) => n.ficheiro), [
        'lec.pdf',
        'x.pdf',
        'y.pdf',
      ]);
      expect(r.naoReconhecidos[0].motivo, contains('E.Leclerc'));
      expect(r.naoReconhecidos[1].motivo, 'Formato de talão não reconhecido');
      expect(r.naoReconhecidos[2].motivo, 'Talão sem data');
    });
  });

  group('loteDosTaloes', () {
    test('compras, linhas, preços e artigos novos', () {
      final r = analisar([('lidl.pdf', _f('lidl'))]);
      final (:lote, aliases: _) = loteDosTaloes(
        r.taloes,
        const {},
        _cat(),
        novoId: _id,
      );

      final compra = lote.compras.single;
      expect(compra['loja_id'], 'lidl');
      expect(compra['local'], 'Lidl Vila Ficticia');
      expect(compra['data'], '2026-10-04');
      expect(compra['total_cent'], 1477);
      expect(compra['poupanca_cent'], 78 + 1 + 50);
      expect(compra['ficheiro'], 'lidl.pdf');
      expect(compra['rever'], isFalse);

      expect(lote.linhas, hasLength(6));
      expect(
        lote.linhas.fold<int>(0, (s, l) => s + (l['pago_cent'] as int)),
        1477,
      );
      final bife = lote.linhas.firstWhere(
        (l) => l['texto_original'] == 'BIFE DE FRANGO',
      );
      expect(bife['artigo_id'], 'a-bife');
      expect(bife['peso_g'], 519);
      expect(bife['quantidade'], isNull);
      expect(bife['preco_unit_cent'], 699);

      expect(lote.precos, hasLength(6));
      expect(lote.precos.every((p) => p['origem'] == 'talao'), isTrue);

      // 4 artigos novos (salada, pão, iogurte, marinadas); bife e gelado existem.
      expect(
        lote.artigos.values.map((a) => a['nome']),
        unorderedEquals([
          'Salada com coentros',
          'Pao forma 14 cereais',
          'Iogurte liquido morango',
          'Marinadas para frango',
        ]),
      );
    });

    test(
      'artigo novo com peso fica em kg; o mesmo texto cria um só artigo',
      () {
        final texto = _f('lidl')
            .replaceFirst('BIFE DE FRANGO 3,63 B', 'PEITO DE PERU 3,63 B');
        final r = analisar([('a.pdf', texto)]);
        final (:lote, aliases: _) = loteDosTaloes(
          r.taloes,
          const {},
          _cat(),
          novoId: _id,
        );
        final peru = lote.artigos.values.firstWhere(
          (a) => a['nome'] == 'Peito de peru',
        );
        expect(peru['unidade'], 'kg');
      },
    );

    test('talões jaExiste e repetidos não entram; aRever entra com rever', () {
      final r = analisar([
        ('a.pdf', _f('lidl')),
        ('a (1).pdf', _f('lidl')),
        (
          'b.pdf',
          _f('pingo_doce').replaceFirst('9,55\nPagamentos', '9,99\nPagamentos'),
        ),
      ]);
      final (:lote, aliases: _) = loteDosTaloes(
        r.taloes,
        const {},
        _cat(),
        novoId: _id,
      );
      expect(lote.compras, hasLength(2));
      expect(lote.compras[1]['rever'], isTrue);
    });

    test('escolhas: ligar a um artigo ou criar com outro nome', () {
      final r = analisar([('lidl.pdf', _f('lidl'))]);
      final (:lote, aliases: _) = loteDosTaloes(
        r.taloes,
        {
          chaveEscolha('lidl', 'SALADA COM COENTROS'): const LigarArtigo(
            'a-gelado',
          ),
          chaveEscolha('lidl', 'MARINADAS PARA FRANGO'): const NovoArtigo(
            nome: 'Marinada de frango',
          ),
        },
        _cat(),
        novoId: _id,
      );
      final salada = lote.linhas.firstWhere(
        (l) => l['texto_original'] == 'SALADA COM COENTROS',
      );
      expect(salada['artigo_id'], 'a-gelado');
      expect(
        lote.artigos.values.map((a) => a['nome']),
        contains('Marinada de frango'),
      );
      expect(
        lote.artigos.values.map((a) => a['nome']),
        isNot(contains('Salada com coentros')),
      );
    });
  });

  group('categoria sugerida e aliases (T6)', () {
    test('a secção do talão sugere a categoria, se existir no catálogo', () {
      final pd = analisar([('pd.pdf', _f('pingo_doce'))]).taloes.single;
      final cat = {
        for (final l in pd.linhas) l.linha.texto: l.categoriaSugerida,
      };
      expect(cat['PESCADA POSTA KG'], 'c-peixe'); // PEIXARIA
      expect(cat['SALADA MISTA'], 'c-fruta'); // FRUTAS E VEGETAIS
      expect(cat['BOLACHA MARIA'], isNull); // Mercearia não está no catálogo
    });

    test('artigo novo fica com a categoria sugerida', () {
      final r = analisar([('pd.pdf', _f('pingo_doce'))]);
      final (:lote, aliases: _) = loteDosTaloes(
        r.taloes,
        const {},
        _cat(),
        novoId: _id,
      );
      final pescada = lote.artigos.values.firstWhere(
        (a) => a['nome'] == 'Pescada posta kg',
      );
      expect(pescada['categoria_id'], 'c-peixe');
    });

    test('aliases: textos sem correspondência e ligações à mão', () {
      final r = analisar([('lidl.pdf', _f('lidl'))]);
      final (:lote, :aliases) = loteDosTaloes(
        r.taloes,
        {
          chaveEscolha('lidl', 'SALADA COM COENTROS'): const LigarArtigo(
            'a-bife',
          ),
        },
        _cat(),
        novoId: _id,
      );
      final porTexto = {for (final a in aliases) a.texto: a};
      // Ligado à mão.
      expect(porTexto['SALADA COM COENTROS']!.artigoId, 'a-bife');
      expect(porTexto['SALADA COM COENTROS']!.lojaId, 'lidl');
      // Artigo novo: o alias aponta para o artigo criado no lote.
      final marinadas = lote.artigos.values.firstWhere(
        (a) => a['nome'] == 'Marinadas para frango',
      );
      expect(porTexto['MARINADAS PARA FRANGO']!.artigoId, marinadas['id']);
      // Já ligados pelo nome ou por um alias existente: sem alias novo.
      expect(porTexto.containsKey('BIFE DE FRANGO'), isFalse);
      expect(porTexto.containsKey('GELADO DOUBLE COCO'), isFalse);
    });

    test('o mesmo texto em dois talões dá um só alias', () {
      final r = analisar([
        ('a.pdf', _f('lidl')),
        (
          'b.pdf',
          _f('lidl').replaceFirst(
            'No : FS 000000000/000001',
            'No : FS 000000000/000002',
          ),
        ),
      ]);
      final (lote: _, :aliases) = loteDosTaloes(
        r.taloes,
        const {},
        _cat(),
        novoId: _id,
      );
      expect(
        aliases.where((a) => a.texto == 'MARINADAS PARA FRANGO'),
        hasLength(1),
      );
    });
  });
}
