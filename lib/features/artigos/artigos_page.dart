import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../data/repositorios.dart';
import '../../domain/modelos.dart';
import '../../domain/texto.dart';
import '../estatisticas/cores.dart';
import '../shell/filtro_pilula.dart';
import '../shell/shell.dart';
import 'dialogos.dart';
import 'ver_artigo.dart';

enum Mostrar {
  artigos('Artigos'),
  categorias('Categorias'),
  lojas('Lojas');

  const Mostrar(this.rotulo);
  final String rotulo;
}

/// Valor do filtro para "artigos sem categoria".
const _semCategoria = '__sem__';

class ArtigosPage extends ConsumerStatefulWidget {
  const ArtigosPage({super.key});

  @override
  ConsumerState<ArtigosPage> createState() => _ArtigosPageState();
}

class _ArtigosPageState extends ConsumerState<ArtigosPage> {
  Mostrar _mostrar = Mostrar.artigos;
  String? _filtroCategoria; // null = todas
  String _pesquisa = '';

  /// Ids escondidos enquanto a eliminação pode ser anulada.
  final _ocultos = <String>{};

  void _mensagem(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  /// Esconde o item e só elimina depois de a SnackBar fechar sem "Anular".
  void _eliminarComAnular({
    required String id,
    required String descricao,
    required Future<void> Function() eliminar,
  }) {
    setState(() => _ocultos.add(id));
    final mensagens = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    mensagens
        .showSnackBar(
          SnackBar(
            content: Text('"$descricao" eliminado.'),
            duration: const Duration(seconds: 5),
            persist: false,
            action: SnackBarAction(label: 'Anular', onPressed: () {}),
          ),
        )
        .closed
        .then((razao) async {
          if (razao == SnackBarClosedReason.action) {
            if (mounted) setState(() => _ocultos.remove(id));
            return;
          }
          try {
            await eliminar();
          } catch (e) {
            if (mounted) {
              setState(() => _ocultos.remove(id));
              mensagens.showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        });
  }

  Future<void> _editarArtigo({
    Artigo? artigo,
    required List<Categoria> categorias,
    required List<Loja> lojas,
    required Map<String, int> precos,
  }) async {
    final r = await showDialog<ResultadoArtigo>(
      context: context,
      builder: (_) => DialogoArtigo(
        artigo: artigo,
        categorias: categorias,
        lojas: lojas,
        precosAtuais: precos,
      ),
    );
    if (r == null) return;
    try {
      await ref
          .read(artigosRepositoryProvider)
          .guardar(
            Artigo(
              id: artigo?.id ?? const Uuid().v4(),
              nome: r.nome,
              categoriaId: r.categoriaId,
              unidade: r.unidade,
              ativo: artigo?.ativo ?? true,
              ean: r.ean,
            ),
            precosCent: r.precosCent,
            novo: artigo == null,
          );
      if (mounted) _mensagem('Artigo guardado.');
    } catch (e) {
      if (mounted) _mensagem('$e');
    }
  }

  Future<void> _editarCategoria({
    Categoria? categoria,
    required List<Categoria> todas,
  }) async {
    final ordemNova = todas.isEmpty
        ? 1
        : todas.map((c) => c.ordem).reduce((a, b) => a > b ? a : b) + 1;
    final r = await showDialog<({String nome, int ordem})>(
      context: context,
      builder: (_) =>
          DialogoCategoria(categoria: categoria, ordemNova: ordemNova),
    );
    if (r == null) return;
    final repo = ref.read(categoriasRepositoryProvider);
    try {
      if (categoria == null) {
        await repo.criar(nome: r.nome, ordem: r.ordem);
      } else {
        await repo.atualizar(categoria.copyWith(nome: r.nome, ordem: r.ordem));
      }
    } catch (e) {
      if (mounted) _mensagem('$e');
    }
  }

  Future<void> _eliminarCategoria(
    Categoria categoria,
    List<Categoria> todas,
    List<Artigo> artigos,
  ) async {
    final repo = ref.read(categoriasRepositoryProvider);
    final n = artigos.where((a) => a.categoriaId == categoria.id).length;
    String? destino;
    if (n > 0) {
      final r = await showDialog<({String? destino})>(
        context: context,
        builder: (_) => DialogoMoverArtigos(
          categoria: categoria,
          nArtigos: n,
          outras: [
            for (final c in todas)
              if (c.id != categoria.id && !_ocultos.contains(c.id)) c,
          ],
        ),
      );
      if (r == null) return;
      destino = r.destino;
    }
    _eliminarComAnular(
      id: categoria.id,
      descricao: categoria.nome,
      eliminar: () => repo.eliminar(categoria.id, moverPara: destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artigos = ref.watch(artigosProvider);
    final categorias = ref.watch(categoriasProvider);
    final lojas = ref.watch(lojasProvider);
    final precos = ref.watch(precosAtuaisProvider);

    final erro = [
      artigos,
      categorias,
      lojas,
      precos,
    ].where((a) => a.hasError).map((a) => a.error).firstOrNull;
    final pronto =
        artigos.hasValue &&
        categorias.hasValue &&
        lojas.hasValue &&
        precos.hasValue;

    final listaCategorias = [
      for (final c in categorias.value ?? const <Categoria>[])
        if (!_ocultos.contains(c.id)) c,
    ];
    final listaLojas = lojas.value ?? const <Loja>[];
    final listaArtigos = artigos.value ?? const <Artigo>[];
    final precosPorArtigo = <String, Map<String, int>>{};
    for (final p in precos.value ?? const <PrecoAtual>[]) {
      (precosPorArtigo[p.artigoId] ??= {})[p.lojaId] = p.precoCent;
    }

    Widget corpo;
    if (erro != null && !pronto) {
      corpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Não foi possível carregar os dados: $erro'),
        ),
      );
    } else if (!pronto) {
      corpo = const Center(child: CircularProgressIndicator());
    } else {
      corpo = switch (_mostrar) {
        Mostrar.artigos => _listaArtigos(
          listaArtigos,
          listaCategorias,
          listaLojas,
          precosPorArtigo,
        ),
        Mostrar.categorias => _listaCategorias(listaCategorias, listaArtigos),
        Mostrar.lojas => _listaLojas(listaLojas),
      };
    }

    return Pagina(
      titulo: 'Artigos e lojas',
      botao: !pronto
          ? null
          : FloatingActionButton.extended(
              onPressed: () => switch (_mostrar) {
                Mostrar.artigos => _editarArtigo(
                  categorias: listaCategorias,
                  lojas: [
                    for (final l in listaLojas)
                      if (!l.arquivada) l,
                  ],
                  precos: const {},
                ),
                Mostrar.categorias => _editarCategoria(todas: listaCategorias),
                Mostrar.lojas => _editarLoja(),
              },
              icon: const Icon(Icons.add),
              label: Text(switch (_mostrar) {
                Mostrar.artigos => 'Novo artigo',
                Mostrar.categorias => 'Nova categoria',
                Mostrar.lojas => 'Nova loja',
              }),
            ),
      filtros: _filtros(listaCategorias),
      pesquisa: _mostrar == Mostrar.artigos
          ? CampoPesquisa(
              dica: 'Pesquisar artigos',
              aoEscrever: (v) => setState(() => _pesquisa = v),
            )
          : null,
      corpo: ConteudoCentrado(child: corpo),
    );
  }

  List<Widget> _filtros(List<Categoria> categorias) {
    final opcoesCategoria = <String?, String>{
      null: 'Todas',
      _semCategoria: 'Sem categoria',
      for (final c in categorias) c.id: c.nome,
    };
    return [
      FiltroPilula<Mostrar>(
        rotulo: 'Mostrar',
        icone: Icons.view_list,
        valor: _mostrar,
        opcoes: {for (final m in Mostrar.values) m: m.rotulo},
        aoMudar: (v) => setState(() => _mostrar = v),
      ),
      if (_mostrar == Mostrar.artigos)
        FiltroPilula<String?>(
          rotulo: 'Categoria',
          icone: Icons.category,
          valor: opcoesCategoria.containsKey(_filtroCategoria)
              ? _filtroCategoria
              : null,
          opcoes: opcoesCategoria,
          aoMudar: (v) => setState(() => _filtroCategoria = v),
        ),
    ];
  }

  Widget _vazio(String texto) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(texto, textAlign: TextAlign.center),
    ),
  );

  Widget _listaArtigos(
    List<Artigo> artigos,
    List<Categoria> categorias,
    List<Loja> lojas,
    Map<String, Map<String, int>> precos,
  ) {
    final nomeCategoria = {for (final c in categorias) c.id: c.nome};
    final termo = normalizar(_pesquisa.trim());
    final filtrados = [
      for (final a in artigos)
        if (!_ocultos.contains(a.id) &&
            switch (_filtroCategoria) {
              null => true,
              _semCategoria => a.categoriaId == null,
              final id => a.categoriaId == id,
            } &&
            artigoCorresponde(a, termo))
          a,
    ];
    if (artigos.isEmpty) {
      return _vazio(
        'Ainda não há artigos. Importa o teu histórico em '
        '"Importar e exportar" ou cria um artigo novo.',
      );
    }
    if (filtrados.isEmpty) return _vazio('Nenhum artigo encontrado.');

    final cores = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: filtrados.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '${formatarInteiro(filtrados.length)} artigos',
              style: TextStyle(color: cores.onSurfaceVariant),
            ),
          );
        }
        final a = filtrados[i - 1];
        final p = precos[a.id] ?? const <String, int>{};
        final porKg = a.unidade == Unidade.kg ? '/kg' : '';
        final partes = [
          nomeCategoria[a.categoriaId] ?? 'Sem categoria',
          for (final l in lojas)
            if (p[l.id] != null) '${l.nome} ${formatarCent(p[l.id]!)}$porKg',
        ];
        return ListTile(
          title: Text(a.nome),
          subtitle: Text(partes.join(' · ')),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ações',
            onSelected: (acao) {
              if (acao == 'ver') {
                showDialog<void>(
                  context: context,
                  builder: (_) => DialogoVerArtigo(artigo: a),
                );
              } else if (acao == 'editar') {
                _editarArtigo(
                  artigo: a,
                  categorias: categorias,
                  lojas: lojas,
                  precos: p,
                );
              } else {
                final repo = ref.read(artigosRepositoryProvider);
                _eliminarComAnular(
                  id: a.id,
                  descricao: a.nome,
                  eliminar: () => repo.eliminar(a.id),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ver', child: Text('Ver')),
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        );
      },
    );
  }

  Widget _listaCategorias(List<Categoria> categorias, List<Artigo> artigos) {
    if (categorias.isEmpty) return _vazio('Ainda não há categorias.');
    final contagem = <String?, int>{};
    for (final a in artigos) {
      if (_ocultos.contains(a.id)) continue;
      contagem.update(a.categoriaId, (n) => n + 1, ifAbsent: () => 1);
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: categorias.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final c = categorias[i];
        final n = contagem[c.id] ?? 0;
        return ListTile(
          title: Text(c.nome),
          subtitle: Text('$n ${n == 1 ? 'artigo' : 'artigos'}'),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ações',
            onSelected: (acao) => acao == 'editar'
                ? _editarCategoria(categoria: c, todas: categorias)
                : _eliminarCategoria(c, categorias, artigos),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editarLoja({Loja? loja}) async {
    final r = await showDialog<Loja>(
      context: context,
      builder: (_) => DialogoLoja(loja: loja),
    );
    if (r == null) return;
    try {
      await ref.read(lojasRepositoryProvider).guardar(r, nova: loja == null);
    } catch (e) {
      if (mounted) _mensagem('$e');
    }
  }

  Future<void> _eliminarLoja(Loja loja) async {
    final repo = ref.read(lojasRepositoryProvider);
    final int n;
    try {
      n = await ref.read(comprasRepositoryProvider).comprasDaLoja(loja.id);
    } on ErroDados catch (e) {
      if (mounted) _mensagem('$e');
      return;
    }
    if (!mounted) return;
    if (n > 0) {
      final arquivar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Não é possível eliminar "${loja.nome}"'),
          content: Text(
            'Esta loja tem $n ${n == 1 ? 'compra' : 'compras'} no histórico. '
            'Podes arquivá-la: deixa de aparecer na Lista, mas as compras '
            'ficam.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Arquivar'),
            ),
          ],
        ),
      );
      if (arquivar == true) await repo.arquivar(loja.id, arquivada: true);
      return;
    }
    _eliminarComAnular(
      id: loja.id,
      descricao: loja.nome,
      eliminar: () => repo.eliminar(loja.id),
    );
  }

  Widget _listaLojas(List<Loja> lojas) {
    final visiveis = [
      for (final l in lojas)
        if (!_ocultos.contains(l.id)) l,
    ];
    if (visiveis.isEmpty) return _vazio('Ainda não há lojas.');
    final cores = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: visiveis.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final l = visiveis[i];
        final detalhes = [
          if (l.cadeia != null && l.cadeia != l.nome) l.cadeia!,
          ?l.local,
          if (l.arquivada) 'Arquivada',
        ];
        return ListTile(
          leading: CircleAvatar(
            radius: 10,
            backgroundColor: corDeHex(l.cor) ?? Colors.grey,
          ),
          title: Text(
            l.nome,
            style: l.arquivada
                ? TextStyle(color: cores.onSurfaceVariant)
                : null,
          ),
          subtitle: detalhes.isEmpty ? null : Text(detalhes.join(' · ')),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ações',
            onSelected: (acao) => switch (acao) {
              'editar' => _editarLoja(loja: l),
              'arquivar' =>
                ref
                    .read(lojasRepositoryProvider)
                    .arquivar(l.id, arquivada: !l.arquivada),
              _ => _eliminarLoja(l),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(
                value: 'arquivar',
                child: Text(l.arquivada ? 'Desarquivar' : 'Arquivar'),
              ),
              const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        );
      },
    );
  }
}

/// Pesquisa de Artigos: pelo nome (sem acentos) ou pelo código de barras.
/// [termo] já vem normalizado.
bool artigoCorresponde(Artigo a, String termo) =>
    termo.isEmpty ||
    normalizar(a.nome).contains(termo) ||
    (a.ean?.contains(termo) ?? false);
