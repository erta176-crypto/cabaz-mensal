/// Importar "Artigos e preços": uma linha por artigo × loja.
library;

import '../domain/modelos.dart';
import 'analise_comum.dart';
import 'campos.dart';
import 'previsualizacao.dart';
import 'tabela_lida.dart';
import 'valores.dart';

Previsualizacao analisarArtigos(
  TabelaLida tabela,
  List<Campo> campos,
  Catalogo cat, {
  bool atualizarExistentes = true,
  DateTime? hoje,
  String Function()? novoId,
}) {
  final col = Colunas(campos);
  final lote = LoteImportacao();
  final r = Resolvedor(cat, lote, novoId: novoId);
  final data = dataIso(hoje ?? DateTime.now());
  final linhas = <LinhaPrevia>[];

  void preco(String artigoId, String lojaId, int cent) => lote.precos.add({
    'id': r.novoId(),
    'artigo_id': artigoId,
    'loja_id': lojaId,
    'data': data,
    'preco_cent': cent,
    'origem': 'manual',
  });

  for (final (i, l) in tabela.linhas.indexed) {
    LinhaPrevia estado(EstadoLinha e, [String? motivo]) =>
        LinhaPrevia(numero: i + 1, valores: l, estado: e, motivo: motivo);

    final nome = col.valor(l, Campo.artigo);
    final categoria = col.valor(l, Campo.categoria);
    final unidadeTxt = col.valor(l, Campo.unidade);
    final lojaTxt = col.valor(l, Campo.loja);
    final precoTxt = col.valor(l, Campo.preco);

    if (nome.isEmpty) {
      linhas.add(estado(EstadoLinha.erro, 'Artigo vazio'));
      continue;
    }
    final unidade = unidadeTxt.isEmpty ? null : unidadeDeTexto(unidadeTxt);
    if (unidadeTxt.isNotEmpty && unidade == null) {
      linhas.add(estado(EstadoLinha.erro, 'Unidade inválida: $unidadeTxt'));
      continue;
    }
    final loja = lojaTxt.isEmpty ? null : cat.loja(lojaTxt);
    if (lojaTxt.isNotEmpty && loja == null) {
      linhas.add(estado(EstadoLinha.erro, 'Loja desconhecida: $lojaTxt'));
      continue;
    }
    final cent = precoTxt.isEmpty ? null : centDeTexto(precoTxt);
    if (precoTxt.isNotEmpty && cent == null) {
      linhas.add(estado(EstadoLinha.erro, 'Preço inválido: $precoTxt'));
      continue;
    }
    if (cent != null && loja == null) {
      linhas.add(estado(EstadoLinha.erro, 'Preço sem loja'));
      continue;
    }

    final existente = r.artigoExistente(nome);
    if (existente == null || r.criadoAqui(existente.id)) {
      final a =
          existente ??
          r.criarArtigo(nome, categoria: categoria, unidade: unidade);
      if (cent != null) preco(a.id, loja!.id, cent);
      linhas.add(estado(EstadoLinha.novo));
      continue;
    }

    final novaCategoria =
        categoria.isNotEmpty &&
        r.categoriaExistente(categoria) != existente.categoriaId;
    final novaUnidade = unidade != null && unidade != existente.unidade;
    final novoPreco = cent != null && cat.preco(existente.id, loja!.id) != cent;
    if (!novaCategoria && !novaUnidade && !novoPreco) {
      linhas.add(estado(EstadoLinha.jaExiste));
      continue;
    }
    if (!atualizarExistentes) {
      linhas.add(estado(EstadoLinha.jaExiste, 'Mantido o que existe'));
      continue;
    }
    lote.artigos[existente.id] = {
      ...existente.toMap(),
      ...?lote.artigos[existente.id],
      if (novaCategoria) 'categoria_id': r.garantirCategoria(categoria),
      if (novaUnidade) 'unidade': unidade.codigo,
    };
    if (novoPreco) preco(existente.id, loja.id, cent);
    linhas.add(estado(EstadoLinha.atualiza));
  }
  return Previsualizacao(linhas: linhas, lote: lote);
}
