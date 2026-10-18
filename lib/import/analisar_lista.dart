/// Importar "Lista de compras" (formato da app e CSV da app antiga
/// "Lista de Compras": Categoria;Artigo;Comprado;Quantidade;Supermercado).
library;

import '../domain/modelos.dart';
import 'analise_comum.dart';
import 'campos.dart';
import 'previsualizacao.dart';
import 'tabela_lida.dart';
import 'valores.dart';

const motivoSemQuantidade = 'Sem quantidade (catálogo da app antiga)';

Previsualizacao analisarLista(
  TabelaLida tabela,
  List<Campo> campos,
  Catalogo cat, {
  Loja? lojaPorOmissao,
  bool incluirSemQuantidade = false,
  String Function()? novoId,
}) {
  final col = Colunas(campos);
  final lote = LoteImportacao();
  final r = Resolvedor(cat, lote, novoId: novoId);
  final linhas = <LinhaPrevia>[];

  for (final (i, l) in tabela.linhas.indexed) {
    LinhaPrevia estado(EstadoLinha e, [String? motivo]) =>
        LinhaPrevia(numero: i + 1, valores: l, estado: e, motivo: motivo);

    final nome = col.valor(l, Campo.artigo);
    final categoria = col.valor(l, Campo.categoria);
    final qtdTxt = col.valor(l, Campo.quantidade);
    if (nome.isEmpty) {
      linhas.add(estado(EstadoLinha.erro, 'Artigo vazio'));
      continue;
    }

    if (qtdTxt.isEmpty) {
      if (!incluirSemQuantidade) {
        linhas.add(estado(EstadoLinha.ignorada, motivoSemQuantidade));
        continue;
      }
      // Só para o catálogo: cria o artigo, não o põe na lista.
      final existe = r.artigoExistente(nome) != null;
      if (!existe) r.criarArtigo(nome, categoria: categoria);
      linhas.add(estado(existe ? EstadoLinha.jaExiste : EstadoLinha.novo));
      continue;
    }

    final lojaTxt = col.valor(l, Campo.loja);
    final loja = lojaTxt.isEmpty ? lojaPorOmissao : cat.loja(lojaTxt);
    if (loja == null) {
      linhas.add(
        estado(
          EstadoLinha.erro,
          lojaTxt.isEmpty
              ? 'Sem loja: escolhe a "Loja para linhas sem supermercado"'
              : 'Loja desconhecida: $lojaTxt',
        ),
      );
      continue;
    }

    final q = lerQuantidadeTexto(qtdTxt);
    final unidade =
        (q.unidade == null ? null : unidadeDeTexto(q.unidade!)) ??
        unidadeDeTexto(col.valor(l, Campo.unidade));
    final existente = r.artigoExistente(nome);
    final novoArtigo = existente == null || r.criadoAqui(existente.id);
    final artigo =
        existente ??
        r.criarArtigo(nome, categoria: categoria, unidade: unidade);
    final item = novoArtigo ? null : cat.item(loja.id, artigo.id);
    final qtd = q.valor ?? item?.qtdPadrao ?? 1;
    final comprado = lerSimNao(col.valor(l, Campo.comprado));

    final igual =
        item != null &&
        item.incluido &&
        (item.qtd - qtd).abs() < 1e-9 &&
        item.comprado == comprado;
    lote.itens['${loja.id}|${artigo.id}'] = {
      'loja_id': loja.id,
      'artigo_id': artigo.id,
      'qtd_padrao': item?.qtdPadrao ?? qtd,
      'qtd': qtd,
      'incluido': true,
      'comprado': comprado,
    };
    if (igual) lote.itens.remove('${loja.id}|${artigo.id}');
    linhas.add(
      estado(
        igual
            ? EstadoLinha.jaExiste
            : (item == null ? EstadoLinha.novo : EstadoLinha.atualiza),
      ),
    );
  }
  return Previsualizacao(linhas: linhas, lote: lote);
}
