import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/import/exportar.dart';
import 'package:cabaz_mensal/import/seed_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync/dispositivo.dart';
import 'sync/servidor_falso.dart';

void main() {
  late Dispositivo d;

  setUp(() => d = Dispositivo(ServidorFalso()));
  tearDown(() => d.fechar());

  Future<Map<String, List<Map<String, dynamic>>>> lerTudo() async => {
    for (final t in [
      'lojas',
      'categorias',
      'artigos',
      'aliases',
      'itens_lista',
      'registos_preco',
      'compras',
      'linhas_compra',
    ])
      t: await d.base.lerTabela(t, incluirApagados: true),
  };

  Future<void> artigoComPrecoEAlias(String lojaId) async {
    await d.escrita.inserir('categorias', {
      'id': 'c1',
      'nome': 'Frescos',
      'ordem': 1,
    });
    await d.escrita.inserir('artigos', {
      'id': 'a1',
      'nome': 'Maçã',
      'categoria_id': 'c1',
      'unidade': Unidade.un.codigo,
    });
    await d.escrita.inserir('registos_preco', {
      'id': 'p1',
      'artigo_id': 'a1',
      'loja_id': lojaId,
      'data': '2026-10-01',
      'preco_cent': 199,
      'origem': 'manual',
    });
    await d.artigos.guardarAlias(lojaId, 'MACA FUJI', 'a1');
  }

  test('eliminar uma loja apaga também aliases e preços dela', () async {
    await d.lojas.guardar(
      const Loja(id: 'l1', slug: 'teste', nome: 'Teste'),
      nova: true,
    );
    await artigoComPrecoEAlias('l1');

    await d.lojas.eliminar('l1');

    final tudo = await lerTudo();
    expect(tudo['aliases']!.every((a) => a['apagado_em'] != null), isTrue);
    expect(
      tudo['registos_preco']!.every((p) => p['apagado_em'] != null),
      isTrue,
    );
  });

  test('a cópia depois de eliminar uma loja é aceite', () async {
    await d.lojas.guardar(
      const Loja(id: 'l1', slug: 'teste', nome: 'Teste'),
      nova: true,
    );
    await artigoComPrecoEAlias('l1');
    await d.lojas.eliminar('l1');

    final texto = exportacaoParaTexto(montarExportacao(await lerTudo()));
    final seed = SeedFicheiro.lerTexto(texto);
    expect(seed.precos, isEmpty);
    expect(seed.aliases, isEmpty);
  });

  test('órfãos de lojas apagadas não entram na cópia', () async {
    await d.lojas.guardar(
      const Loja(id: 'l1', slug: 'teste', nome: 'Teste'),
      nova: true,
    );
    await artigoComPrecoEAlias('l1');
    // Simula dados antigos: loja apagada, mas preço e alias ainda ativos.
    await d.escrita.apagar('lojas', 'l1');

    final texto = exportacaoParaTexto(montarExportacao(await lerTudo()));
    final seed = SeedFicheiro.lerTexto(texto);
    expect(seed.precos, isEmpty);
    expect(seed.aliases, isEmpty);
  });
}
