/// Montagem da Lista do mês a partir dos dados em cache (sem interface,
/// para poder ser testada).
library;

import '../../domain/compra.dart';
import '../../domain/modelos.dart';
import '../../domain/preferencias.dart';

class LinhaLista {
  const LinhaLista({
    required this.item,
    required this.artigo,
    required this.precoCent,
  });

  final ItemLista item;
  final Artigo artigo;

  /// Último preço conhecido nesta loja (por kg nos artigos ao peso).
  final int? precoCent;

  int? get estimadoCent => valorEstimadoCent(artigo.unidade, item.qtd, precoCent);
}

class GrupoLista {
  const GrupoLista({
    required this.chave,
    required this.titulo,
    required this.linhas,
  });

  /// "loja|categoria", usada para guardar se o grupo está fechado.
  final String chave;
  final String titulo;
  final List<LinhaLista> linhas;

  int get comprados => linhas.where((l) => l.item.comprado).length;
}

class SecaoLista {
  const SecaoLista({required this.loja, required this.grupos});

  final Loja loja;
  final List<GrupoLista> grupos;

  Iterable<LinhaLista> get linhas => grupos.expand((g) => g.linhas);
}

class ListaMontada {
  const ListaMontada(this.secoes);

  final List<SecaoLista> secoes;

  Iterable<LinhaLista> get linhas => secoes.expand((s) => s.linhas);

  /// Total estimado dos artigos incluídos (qtd × último preço).
  int get totalEstimadoCent => linhas
      .where((l) => l.item.incluido)
      .fold(0, (s, l) => s + (l.estimadoCent ?? 0));

  /// Total estimado do que já está no carrinho (comprado).
  int get totalCarrinhoCent => linhas
      .where((l) => l.item.comprado)
      .fold(0, (s, l) => s + (l.estimadoCent ?? 0));

  int get nComprados => linhas.where((l) => l.item.comprado).length;
}

const semCategoria = '__sem__';

ListaMontada montarLista({
  required List<Loja> lojas,
  required List<Categoria> categorias,
  required List<Artigo> artigos,
  required List<ItemLista> itens,
  required List<PrecoAtual> precos,
  required Preferencias preferencias,
}) {
  final artigoPorId = {for (final a in artigos) a.id: a};
  final categoriaPorId = {for (final c in categorias) c.id: c};
  final preco = {for (final p in precos) '${p.artigoId}|${p.lojaId}': p.precoCent};
  final planear = preferencias.modo == ModoLista.planear;

  final ativas = lojas.where((l) => !l.arquivada).toList();
  final escolhidas = preferencias.lojaId == null
      ? ativas
      : ativas.where((l) => l.id == preferencias.lojaId).toList();

  int ordemLinhas(LinhaLista a, LinhaLista b) {
    // No supermercado, os comprados vão para o fim do grupo.
    if (!planear && a.item.comprado != b.item.comprado) {
      return a.item.comprado ? 1 : -1;
    }
    return a.artigo.nome.toLowerCase().compareTo(b.artigo.nome.toLowerCase());
  }

  final secoes = <SecaoLista>[];
  for (final loja in escolhidas) {
    final linhas = [
      for (final i in itens)
        if (i.lojaId == loja.id &&
            (planear || i.incluido) &&
            artigoPorId.containsKey(i.artigoId))
          LinhaLista(
            item: i,
            artigo: artigoPorId[i.artigoId]!,
            precoCent: preco['${i.artigoId}|${loja.id}'],
          ),
    ];

    final grupos = <GrupoLista>[];
    if (preferencias.organizar == Organizar.porArtigo) {
      grupos.add(
        GrupoLista(
          chave: '${loja.id}|todos',
          titulo: 'Artigos',
          linhas: linhas..sort(ordemLinhas),
        ),
      );
    } else {
      final porCategoria = <String, List<LinhaLista>>{};
      for (final l in linhas) {
        final c = l.artigo.categoriaId;
        final chave = c != null && categoriaPorId.containsKey(c)
            ? c
            : semCategoria;
        (porCategoria[chave] ??= []).add(l);
      }
      final chaves = porCategoria.keys.toList()
        ..sort((a, b) {
          if (a == semCategoria) return 1;
          if (b == semCategoria) return -1;
          return categoriaPorId[a]!.ordem.compareTo(categoriaPorId[b]!.ordem);
        });
      for (final c in chaves) {
        grupos.add(
          GrupoLista(
            chave: '${loja.id}|$c',
            titulo: c == semCategoria
                ? 'Sem categoria'
                : categoriaPorId[c]!.nome,
            linhas: porCategoria[c]!..sort(ordemLinhas),
          ),
        );
      }
    }
    secoes.add(SecaoLista(loja: loja, grupos: grupos));
  }
  return ListaMontada(secoes);
}

/// Quantidade para mostrar: "2 un", "1,3 kg".
String formatarQtd(num qtd, Unidade unidade) {
  final texto = qtd == qtd.roundToDouble()
      ? qtd.toInt().toString()
      : qtd.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');
  return '$texto ${unidade.codigo}';
}

/// Lista em texto simples, por categoria, para partilhar.
String listaEmTexto(ListaMontada lista) {
  final b = StringBuffer();
  for (final s in lista.secoes) {
    final linhas = s.linhas.where((l) => l.item.incluido).toList();
    if (linhas.isEmpty) continue;
    b.writeln('🛒 ${s.loja.nome}');
    for (final g in s.grupos) {
      final doGrupo = g.linhas.where((l) => l.item.incluido).toList();
      if (doGrupo.isEmpty) continue;
      b.writeln();
      b.writeln(g.titulo.toUpperCase());
      for (final l in doGrupo) {
        final marca = l.item.comprado ? '☑' : '☐';
        b.writeln('$marca ${l.artigo.nome} — ${formatarQtd(l.item.qtd, l.artigo.unidade)}');
      }
    }
    b.writeln();
  }
  return b.toString().trimRight();
}
