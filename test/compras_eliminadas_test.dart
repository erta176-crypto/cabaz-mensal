import 'package:cabaz_mensal/data/supabase/supabase_repositorios.dart';
import 'package:cabaz_mensal/export/dados_export.dart';
import 'package:cabaz_mensal/import/exportar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tabelas como as lê o lerTudo: c1 ativa, c2 eliminada (Fase 15).
Map<String, List<Map<String, dynamic>>> _tudo() => {
  'lojas': [
    {'id': 'l1', 'slug': 'lidl', 'nome': 'Lidl', 'apagado_em': null},
  ],
  'categorias': <Map<String, dynamic>>[],
  'artigos': [
    {
      'id': 'a1',
      'nome': 'Leite',
      'categoria_id': null,
      'unidade': 'un',
      'apagado_em': null,
    },
  ],
  'compras': [
    {
      'id': 'c1',
      'loja_id': 'l1',
      'local': null,
      'data': '2026-11-01',
      'total_cent': 300,
      'origem': 'importacao',
      'ficheiro': null,
      'apagado_em': null,
    },
    {
      'id': 'c2',
      'loja_id': 'l1',
      'local': null,
      'data': '2026-11-02',
      'total_cent': 500,
      'origem': 'importacao',
      'ficheiro': null,
      'apagado_em': '2026-11-25T10:00:00Z',
    },
  ],
  'linhas_compra': [
    for (final (id, compra, pago) in [
      ('x1', 'c1', 300),
      ('x2', 'c2', 200),
      ('x3', 'c2', 300),
    ])
      {
        'id': id,
        'compra_id': compra,
        'artigo_id': 'a1',
        'texto_original': 'LEITE',
        'quantidade': 1,
        'peso_g': null,
        'preco_unit_cent': pago,
        'bruto_cent': pago,
        'desconto_cent': 0,
        'pago_cent': pago,
      },
  ],
  'registos_preco': <Map<String, dynamic>>[],
  'aliases': <Map<String, dynamic>>[],
  'itens_lista': <Map<String, dynamic>>[],
};

void main() {
  group('semComprasEliminadas', () {
    test('retira as compras eliminadas e só as suas linhas', () {
      final tudo = _tudo();
      final r = semComprasEliminadas(tudo);
      expect([for (final c in r['compras']!) c['id']], ['c1']);
      expect([for (final l in r['linhas_compra']!) l['id']], ['x1']);
    });

    test('as outras tabelas ficam iguais', () {
      final tudo = _tudo();
      final r = semComprasEliminadas(tudo);
      for (final t in ['lojas', 'categorias', 'artigos', 'registos_preco']) {
        expect(r[t], same(tudo[t]), reason: t);
      }
    });

    test('sem compras eliminadas: tudo igual', () {
      final tudo = _tudo()
        ..['compras'] = [_tudo()['compras']!.first]
        ..['linhas_compra'] = [_tudo()['linhas_compra']!.first];
      final r = semComprasEliminadas(tudo);
      expect(r['compras'], hasLength(1));
      expect(r['linhas_compra'], hasLength(1));
    });

    test('a cópia JSON sai sem a compra eliminada nem as suas linhas', () {
      final copia = montarExportacao(semComprasEliminadas(_tudo()));
      expect([for (final c in copia['compras'] as List) c['id']], ['c1']);
      expect([for (final l in copia['linhas'] as List) l['compra_id']], ['c1']);
    });

    test('a exportação de compras também', () {
      final folhas = tabelasCompras(semComprasEliminadas(_tudo()));
      final linhas = folhas.firstWhere((f) => f.nome == 'Linhas').linhas;
      expect(linhas, hasLength(1));
    });
  });

  test('comprasExistentesDe: ignora as eliminadas (o talão pode ser '
      'importado de novo)', () {
    final r = comprasExistentesDe(_tudo()['compras']!);
    expect(r, hasLength(1));
    expect(r.single.lojaId, 'l1');
    expect(r.single.data, '2026-11-01');
    expect(r.single.local, isNull);
    expect(r.single.totalCent, 300);
  });
}
