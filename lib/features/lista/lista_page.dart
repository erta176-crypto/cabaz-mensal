import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ficheiros/guardar_ficheiro.dart';
import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/modelos.dart';
import '../../domain/preferencias.dart';
import '../artigos/artigos_page.dart' show corDeHex;
import '../shell/shell.dart';
import 'adicionar_artigo.dart';
import 'concluir_compra_page.dart';
import 'dialogos_lista.dart';
import 'lista_logica.dart';

class ListaPage extends ConsumerStatefulWidget {
  const ListaPage({super.key});

  @override
  ConsumerState<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends ConsumerState<ListaPage> {
  void _mensagem(String texto, {SnackBarAction? acao}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          action: acao,
          persist: false,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  Preferencias get _prefs =>
      ref.read(preferenciasProvider).value ?? const Preferencias();

  Future<void> _guardarPrefs(Preferencias p) =>
      ref.read(preferenciasRepositoryProvider).guardar(p);

  Future<void> _executar(AcaoGesto acao, LinhaLista l) async {
    final repo = ref.read(listaRepositoryProvider);
    switch (acao) {
      case AcaoGesto.marcarComprado:
        await repo.marcarComprado(l.item, comprado: !l.item.comprado);
      case AcaoGesto.removerDaLista:
        final anterior = l.item;
        await repo.definirIncluido(l.item, incluido: false);
        if (!mounted) return;
        _mensagem(
          '"${l.artigo.nome}" removido da lista.',
          acao: SnackBarAction(
            label: 'Anular',
            onPressed: () => repo.repor(anterior),
          ),
        );
      case AcaoGesto.alterarQuantidade:
        await _alterarQuantidade(l);
      case AcaoGesto.nada:
        break;
    }
  }

  Future<void> _alterarQuantidade(LinhaLista l) async {
    final planear = _prefs.modo == ModoLista.planear;
    final qtd = await showDialog<num>(
      context: context,
      builder: (_) => DialogoQuantidade(
        titulo: planear ? 'Quantidade habitual' : 'Quantidade',
        artigo: l.artigo,
        inicial: planear ? l.item.qtdPadrao : l.item.qtd,
      ),
    );
    if (qtd == null) return;
    final repo = ref.read(listaRepositoryProvider);
    if (planear) {
      await repo.alterarQtdPadrao(l.item, qtd);
    } else {
      await repo.alterarQtd(l.item, qtd);
    }
  }

  Future<void> _verArtigo(LinhaLista l) => showDialog<void>(
    context: context,
    builder: (_) => DialogoVerArtigo(artigo: l.artigo),
  );

  Future<void> _alternarGrupo(String chave) {
    final p = _prefs;
    final fechados = {...p.gruposFechados};
    if (!fechados.remove(chave)) fechados.add(chave);
    return _guardarPrefs(p.copyWith(gruposFechados: fechados));
  }

  Future<void> _partilhar(ListaMontada lista) async {
    final texto = listaEmTexto(lista);
    if (texto.isEmpty) {
      _mensagem('A lista está vazia.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: texto));
    final descarregado = await partilharTexto(
      'lista-${DateTime.now().toIso8601String().substring(0, 10)}',
      texto,
    );
    if (descarregado && mounted) {
      _mensagem('Lista copiada e descarregada em .txt.');
    }
  }

  Future<void> _adicionar(List<Loja> lojas) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => AdicionarArtigoSheet(lojaInicial: _prefs.lojaId),
    );
    if (r != null && mounted) _mensagem(r);
  }

  void _concluir() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ConcluirCompraPage(lojaId: _prefs.lojaId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lojas = ref.watch(lojasProvider);
    final categorias = ref.watch(categoriasProvider);
    final artigos = ref.watch(artigosProvider);
    final itens = ref.watch(itensListaProvider);
    final precos = ref.watch(precosAtuaisProvider);
    final prefsAsync = ref.watch(preferenciasProvider);

    final pronto = [
      lojas,
      categorias,
      artigos,
      itens,
      precos,
      prefsAsync,
    ].every((a) => a.hasValue);

    if (!pronto) {
      return const Pagina(
        titulo: 'Lista do mês',
        corpo: Center(child: CircularProgressIndicator()),
      );
    }

    final prefs = prefsAsync.value!;
    final ativas = lojas.value!.where((l) => !l.arquivada).toList();
    final lista = montarLista(
      lojas: lojas.value!,
      categorias: categorias.value!,
      artigos: artigos.value!,
      itens: itens.value!,
      precos: precos.value!,
      preferencias: prefs,
    );
    final planear = prefs.modo == ModoLista.planear;

    return Pagina(
      titulo: 'Lista do mês',
      acoes: [
        IconButton(
          tooltip: 'Partilhar lista',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _partilhar(lista),
        ),
      ],
      botao: ativas.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _adicionar(ativas),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar artigo'),
            ),
      corpo: ConteudoCentrado(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _Menus(
                prefs: prefs,
                lojas: ativas,
                aoMudar: _guardarPrefs,
              ),
            ),
            Expanded(
              child: ativas.isEmpty
                  ? const _Vazio(
                      'Ainda não há lojas. Importa os teus dados em '
                      '"Importar e exportar" ou cria uma loja em "Artigos".',
                    )
                  : lista.linhas.isEmpty
                  ? _Vazio(
                      planear
                          ? 'Ainda não há artigos habituais nesta loja. '
                                'Usa "Adicionar artigo".'
                          : 'A lista está vazia. Usa "Adicionar artigo" ou '
                                'o modo Planear.',
                    )
                  : _Conteudo(
                      lista: lista,
                      prefs: prefs,
                      aoGesto: _executar,
                      aoAlternarGrupo: _alternarGrupo,
                      aoAlterarQtd: _alterarQuantidade,
                      aoVer: _verArtigo,
                    ),
            ),
            if (!planear)
              _Rodape(
                lista: lista,
                aoConcluir: lista.nComprados == 0 ? null : _concluir,
              ),
          ],
        ),
      ),
    );
  }
}

class _Menus extends StatelessWidget {
  const _Menus({
    required this.prefs,
    required this.lojas,
    required this.aoMudar,
  });

  final Preferencias prefs;
  final List<Loja> lojas;
  final Future<void> Function(Preferencias) aoMudar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final estreito = c.maxWidth < 600;
        double largura(double l) => estreito ? c.maxWidth : l;
        final lojaValida = lojas.any((l) => l.id == prefs.lojaId)
            ? prefs.lojaId
            : null;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DropdownMenu<String?>(
              key: ValueKey('loja-$lojaValida-${lojas.length}'),
              label: const Text('Loja'),
              width: largura(220),
              initialSelection: lojaValida,
              onSelected: (v) => aoMudar(prefs.copyWith(lojaId: () => v)),
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: null, label: 'Todas as lojas'),
                for (final l in lojas)
                  DropdownMenuEntry(value: l.id, label: l.nome),
              ],
            ),
            DropdownMenu<Organizar>(
              key: ValueKey('org-${prefs.organizar}'),
              label: const Text('Organizar'),
              width: largura(220),
              initialSelection: prefs.organizar,
              onSelected: (v) =>
                  v == null ? null : aoMudar(prefs.copyWith(organizar: v)),
              dropdownMenuEntries: [
                for (final o in Organizar.values)
                  DropdownMenuEntry(value: o, label: o.rotulo),
              ],
            ),
            DropdownMenu<ModoLista>(
              key: ValueKey('modo-${prefs.modo}'),
              label: const Text('Modo'),
              width: largura(220),
              initialSelection: prefs.modo,
              onSelected: (v) =>
                  v == null ? null : aoMudar(prefs.copyWith(modo: v)),
              dropdownMenuEntries: [
                for (final m in ModoLista.values)
                  DropdownMenuEntry(value: m, label: m.rotulo),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({
    required this.lista,
    required this.prefs,
    required this.aoGesto,
    required this.aoAlternarGrupo,
    required this.aoAlterarQtd,
    required this.aoVer,
  });

  final ListaMontada lista;
  final Preferencias prefs;
  final Future<void> Function(AcaoGesto, LinhaLista) aoGesto;
  final Future<void> Function(String chave) aoAlternarGrupo;
  final Future<void> Function(LinhaLista) aoAlterarQtd;
  final Future<void> Function(LinhaLista) aoVer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variasLojas = lista.secoes.length > 1;
    final porCategoria = prefs.organizar == Organizar.porCategoria;
    final planear = prefs.modo == ModoLista.planear;
    final tema = Theme.of(context);

    final filhos = <Widget>[];
    for (final s in lista.secoes) {
      if (s.linhas.isEmpty) continue;
      if (variasLojas) {
        filhos.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 7,
                  backgroundColor: corDeHex(s.loja.cor) ?? tema.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(s.loja.nome, style: tema.textTheme.titleLarge),
              ],
            ),
          ),
        );
      }
      for (final g in s.grupos) {
        final fechado = porCategoria && prefs.gruposFechados.contains(g.chave);
        if (porCategoria) {
          filhos.add(
            _CabecalhoGrupo(
              grupo: g,
              fechado: fechado,
              aoTocar: () => aoAlternarGrupo(g.chave),
            ),
          );
        }
        if (fechado) continue;
        for (final l in g.linhas) {
          filhos.add(
            planear
                ? _LinhaPlanear(
                    linha: l,
                    aoAlterarQtd: aoAlterarQtd,
                    aoVer: aoVer,
                  )
                : _LinhaSupermercado(
                    linha: l,
                    prefs: prefs,
                    aoGesto: aoGesto,
                    aoAlterarQtd: aoAlterarQtd,
                    aoVer: aoVer,
                  ),
          );
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: filhos,
    );
  }
}

class _CabecalhoGrupo extends StatelessWidget {
  const _CabecalhoGrupo({
    required this.grupo,
    required this.fechado,
    required this.aoTocar,
  });

  final GrupoLista grupo;
  final bool fechado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                grupo.titulo,
                style: tema.textTheme.titleSmall?.copyWith(
                  color: tema.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${grupo.comprados}/${grupo.linhas.length}',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
            Icon(
              fechado ? Icons.expand_more : Icons.expand_less,
              semanticLabel: fechado ? 'Abrir grupo' : 'Fechar grupo',
            ),
          ],
        ),
      ),
    );
  }
}

String _subtitulo(LinhaLista l, {bool habitual = false}) {
  final qtd = formatarQtd(habitual ? l.item.qtdPadrao : l.item.qtd, l.artigo.unidade);
  if (l.precoCent == null) return '$qtd · sem preço';
  final porKg = l.artigo.unidade == Unidade.kg ? '/kg' : '';
  final estimado = l.estimadoCent;
  return '$qtd · ${formatarCent(l.precoCent!)}$porKg'
      '${estimado == null ? '' : ' · ≈ ${formatarCent(estimado)}'}';
}

class _MenuLinha extends StatelessWidget {
  const _MenuLinha({
    required this.linha,
    required this.aoAlterarQtd,
    required this.aoVer,
    required this.aoRemover,
  });

  final LinhaLista linha;
  final Future<void> Function(LinhaLista) aoAlterarQtd;
  final Future<void> Function(LinhaLista) aoVer;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    tooltip: 'Ações',
    onSelected: (a) => switch (a) {
      'qtd' => aoAlterarQtd(linha),
      'ver' => aoVer(linha),
      _ => aoRemover?.call(),
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'qtd', child: Text('Alterar quantidade')),
      const PopupMenuItem(value: 'ver', child: Text('Ver artigo')),
      if (aoRemover != null)
        const PopupMenuItem(value: 'remover', child: Text('Remover da lista')),
    ],
  );
}

class _LinhaSupermercado extends StatelessWidget {
  const _LinhaSupermercado({
    required this.linha,
    required this.prefs,
    required this.aoGesto,
    required this.aoAlterarQtd,
    required this.aoVer,
  });

  final LinhaLista linha;
  final Preferencias prefs;
  final Future<void> Function(AcaoGesto, LinhaLista) aoGesto;
  final Future<void> Function(LinhaLista) aoAlterarQtd;
  final Future<void> Function(LinhaLista) aoVer;

  Widget _fundo(BuildContext context, AcaoGesto acao, Alignment lado) {
    final cores = Theme.of(context).colorScheme;
    final (icone, cor) = switch (acao) {
      AcaoGesto.marcarComprado => (Icons.shopping_cart_checkout, Colors.green.shade700),
      AcaoGesto.removerDaLista => (Icons.remove_circle_outline, cores.error),
      AcaoGesto.alterarQuantidade => (Icons.edit_outlined, cores.primary),
      AcaoGesto.nada => (Icons.block, cores.outline),
    };
    return Container(
      color: cor.withValues(alpha: 0.15),
      alignment: lado,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 8),
          Text(acao.rotulo, style: TextStyle(color: cor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = linha;
    final cores = Theme.of(context).colorScheme;
    final comprado = l.item.comprado;
    final direcao = switch ((prefs.direita, prefs.esquerda)) {
      (AcaoGesto.nada, AcaoGesto.nada) => DismissDirection.none,
      (AcaoGesto.nada, _) => DismissDirection.endToStart,
      (_, AcaoGesto.nada) => DismissDirection.startToEnd,
      _ => DismissDirection.horizontal,
    };

    return Dismissible(
      key: ValueKey('item-${l.item.lojaId}-${l.item.artigoId}'),
      direction: direcao,
      background: _fundo(context, prefs.direita, Alignment.centerLeft),
      secondaryBackground: _fundo(context, prefs.esquerda, Alignment.centerRight),
      // A ação é feita aqui e a linha fica: a cache atualiza a lista.
      confirmDismiss: (d) async {
        await aoGesto(
          d == DismissDirection.startToEnd ? prefs.direita : prefs.esquerda,
          l,
        );
        return false;
      },
      child: ListTile(
        onTap: () => aoGesto(prefs.tocar, l),
        leading: Icon(
          comprado ? Icons.check_circle : Icons.radio_button_unchecked,
          color: comprado ? Colors.green.shade700 : cores.outline,
        ),
        title: Text(
          l.artigo.nome,
          style: comprado
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: cores.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Text(_subtitulo(l)),
        trailing: _MenuLinha(
          linha: l,
          aoAlterarQtd: aoAlterarQtd,
          aoVer: aoVer,
          aoRemover: () => aoGesto(AcaoGesto.removerDaLista, l),
        ),
      ),
    );
  }
}

class _LinhaPlanear extends ConsumerWidget {
  const _LinhaPlanear({
    required this.linha,
    required this.aoAlterarQtd,
    required this.aoVer,
  });

  final LinhaLista linha;
  final Future<void> Function(LinhaLista) aoAlterarQtd;
  final Future<void> Function(LinhaLista) aoVer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = linha;
    final repo = ref.read(listaRepositoryProvider);
    return ListTile(
      onTap: () => aoAlterarQtd(l),
      leading: Switch(
        value: l.item.incluido,
        onChanged: (v) => v
            ? repo.incluir(
                lojaId: l.item.lojaId,
                artigoId: l.item.artigoId,
                qtd: l.item.qtdPadrao,
              )
            : repo.definirIncluido(l.item, incluido: false),
      ),
      title: Text(l.artigo.nome),
      subtitle: Text('Habitual: ${_subtitulo(l, habitual: true)}'),
      trailing: _MenuLinha(
        linha: l,
        aoAlterarQtd: aoAlterarQtd,
        aoVer: aoVer,
        aoRemover: l.item.incluido
            ? () => repo.definirIncluido(l.item, incluido: false)
            : null,
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.lista, required this.aoConcluir});

  final ListaMontada lista;
  final VoidCallback? aoConcluir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget valor(String rotulo, int cent) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(formatarCent(cent), style: tema.textTheme.titleMedium),
      ],
    );
    return Material(
      color: tema.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    valor('Estimado', lista.totalEstimadoCent),
                    valor('No carrinho', lista.totalCarrinhoCent),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: aoConcluir,
                icon: const Icon(Icons.done_all),
                label: const Text('Concluir compra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(texto, textAlign: TextAlign.center),
    ),
  );
}
