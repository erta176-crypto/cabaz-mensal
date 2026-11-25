import 'package:cabaz_mensal/domain/estatisticas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê a resposta da RPC artigos_do_painel e soma o total', () {
    final d = DetalhePainel.fromJson({
      'artigos': [
        {
          'artigo_id': 'a1',
          'total_cent': 1480,
          'quantidade': 2,
          'peso_g': 0,
          'n_compras': 2,
        },
        {
          'artigo_id': 'a2',
          'total_cent': 954.0, // o jsonb pode trazer num
          'quantidade': 0,
          'peso_g': 1250,
          'n_compras': 4,
        },
      ],
      'sem_artigo_cent': 30,
      'diferenca_cent': -5,
    });
    expect([for (final a in d.artigos) a.artigoId], ['a1', 'a2']);
    expect(d.artigos.first.quantidade, 2);
    expect(d.artigos.first.nCompras, 2);
    expect(d.artigos.first.porPeso, isFalse);
    expect(d.artigos.last.pesoG, 1250);
    expect(d.artigos.last.porPeso, isTrue);
    expect(d.semArtigoCent, 30);
    expect(d.diferencaCent, -5);
    // Artigos + sem artigo + diferença = valor da barra (Fase 14, D3).
    expect(d.totalCent, 1480 + 954 + 30 - 5);
  });

  test('sem artigos: total 0', () {
    final d = DetalhePainel.fromJson({
      'artigos': <Object>[],
      'sem_artigo_cent': 0,
      'diferenca_cent': 0,
    });
    expect(d.artigos, isEmpty);
    expect(d.totalCent, 0);
  });

  test('BarraPainel: igualdade por valor, também com listas novas', () {
    const filtro = (periodo: Periodo.esteMes, lojaId: null);
    final a = BarraPainel(filtro: filtro, categoriaIds: ['c1', 'c2']);
    final b = BarraPainel(filtro: filtro, categoriaIds: ['c1', 'c2']);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a == BarraPainel(filtro: filtro, categoriaIds: ['c2', 'c1']),
      isFalse,
    );
    expect(
      a ==
          BarraPainel(
            filtro: filtro,
            categoriaIds: ['c1', 'c2'],
            semCategoria: true,
          ),
      isFalse,
    );
    expect(
      const BarraPainel(filtro: filtro, lojaId: 'l1') ==
          const BarraPainel(
            filtro: (periodo: Periodo.tudo, lojaId: null),
            lojaId: 'l1',
          ),
      isFalse,
    );
  });
}
