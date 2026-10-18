import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../domain/modelos.dart';
import '../../domain/texto.dart';
import 'dialogos_lista.dart';
import 'lista_logica.dart' show formatarQtd;

/// Pesquisa no catálogo (nome e textos de talão, sem acentos nem
/// maiúsculas) e junta à lista da loja. Sem resultados, cria o artigo.
/// Funciona sem rede (tudo vai para a cache e a fila).
/// Fecha com uma mensagem para mostrar (ou null se cancelado).
class AdicionarArtigoSheet extends ConsumerStatefulWidget {
  const AdicionarArtigoSheet({super.key, this.lojaInicial});

  final String? lojaInicial;

  @override
  ConsumerState<AdicionarArtigoSheet> createState() =>
      _AdicionarArtigoSheetState();
}

class _AdicionarArtigoSheetState extends ConsumerState<AdicionarArtigoSheet> {
  final _pesquisa = TextEditingController();
  String? _lojaId;
  String? _categoriaId;
  Unidade _unidade = Unidade.un;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _lojaId = widget.lojaInicial;
  }

  @override
  void dispose() {
    _pesquisa.dispose();
    super.dispose();
  }

  Loja? _loja(List<Loja> lojas) =>
      lojas.where((l) => l.id == _lojaId).firstOrNull ?? lojas.firstOrNull;

  Future<void> _juntar(Artigo artigo, Loja loja, ItemLista? existente) async {
    final qtd = await showDialog<num>(
      context: context,
      builder: (_) => DialogoQuantidade(
        titulo: 'Juntar à lista do ${loja.nome}',
        artigo: artigo,
        inicial: existente?.qtdPadrao ?? 1,
      ),
    );
    if (qtd == null) return;
    await ref
        .read(listaRepositoryProvider)
        .incluir(lojaId: loja.id, artigoId: artigo.id, qtd: qtd);
    if (mounted) {
      Navigator.pop(context, '"${artigo.nome}" juntado à lista do ${loja.nome}.');
    }
  }

  Future<void> _criar(Loja loja) async {
    final nome = _pesquisa.text.trim();
    if (nome.isEmpty) return;
    setState(() => _ocupado = true);
    try {
      // Um artigo eliminado com o mesmo nome volta na mesma linha (mesmo id).
      final repo = ref.read(artigosRepositoryProvider);
      final apagado = (await repo.apagados())
          .where((a) => normalizar(a.nome) == normalizar(nome))
          .firstOrNull;
      final artigo = Artigo(
        id: apagado?.id ?? const Uuid().v4(),
        nome: nome,
        categoriaId: _categoriaId,
        unidade: _unidade,
      );
      await repo.guardar(artigo, novo: true);
      await ref
          .read(listaRepositoryProvider)
          .incluir(lojaId: loja.id, artigoId: artigo.id, qtd: 1);
      if (mounted) {
        Navigator.pop(context, 'Artigo "$nome" criado e juntado à lista.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lojas = [
      for (final l in ref.watch(lojasProvider).value ?? const <Loja>[])
        if (!l.arquivada) l,
    ];
    final artigos = ref.watch(artigosProvider).value ?? const <Artigo>[];
    final aliases = ref.watch(aliasesProvider).value ?? const {};
    final categorias = ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final itens = ref.watch(itensListaProvider).value ?? const <ItemLista>[];
    final loja = _loja(lojas);
    final termo = _pesquisa.text.trim();
    final tema = Theme.of(context);

    final resultados = termo.isEmpty
        ? const <Artigo>[]
        : [
            for (final a in artigos)
              if (a.ativo && correspondeA(termo, [a.nome, ...?aliases[a.id]])) a,
          ];
    final naLista = {
      for (final i in itens)
        if (i.lojaId == loja?.id) i.artigoId: i,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adicionar artigo', style: tema.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (loja != null)
              DropdownMenu<String>(
                label: const Text('Loja'),
                expandedInsets: EdgeInsets.zero,
                initialSelection: loja.id,
                onSelected: (v) => setState(() => _lojaId = v),
                dropdownMenuEntries: [
                  for (final l in lojas)
                    DropdownMenuEntry(value: l.id, label: l.nome),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _pesquisa,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pesquisar no catálogo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loja == null
                  ? const Center(child: Text('Cria primeiro uma loja.'))
                  : termo.isEmpty
                  ? Center(
                      child: Text(
                        'Escreve o nome do artigo ou o texto do talão.',
                        style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : resultados.isEmpty
                  ? SingleChildScrollView(
                      child: _CriarArtigo(
                        nome: termo,
                        categorias: categorias,
                        categoriaId: _categoriaId,
                        unidade: _unidade,
                        ocupado: _ocupado,
                        aoMudarCategoria: (v) => setState(() => _categoriaId = v),
                        aoMudarUnidade: (v) => setState(() => _unidade = v),
                        aoCriar: () => _criar(loja),
                      ),
                    )
                  : ListView.builder(
                      itemCount: resultados.length.clamp(0, 60),
                      itemBuilder: (context, i) {
                        final a = resultados[i];
                        final item = naLista[a.id];
                        final jaNaLista = item != null && item.incluido;
                        return ListTile(
                          title: Text(a.nome),
                          subtitle: Text(
                            jaNaLista
                                ? 'Já na lista · ${formatarQtd(item.qtd, a.unidade)}'
                                : a.unidade.rotulo,
                          ),
                          trailing: Icon(
                            jaNaLista ? Icons.check : Icons.add,
                            color: tema.colorScheme.primary,
                          ),
                          onTap: () => _juntar(a, loja, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriarArtigo extends StatelessWidget {
  const _CriarArtigo({
    required this.nome,
    required this.categorias,
    required this.categoriaId,
    required this.unidade,
    required this.ocupado,
    required this.aoMudarCategoria,
    required this.aoMudarUnidade,
    required this.aoCriar,
  });

  final String nome;
  final List<Categoria> categorias;
  final String? categoriaId;
  final Unidade unidade;
  final bool ocupado;
  final ValueChanged<String?> aoMudarCategoria;
  final ValueChanged<Unidade> aoMudarUnidade;
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nenhum artigo encontrado.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: categoriaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                for (final c in categorias)
                  DropdownMenuItem(value: c.id, child: Text(c.nome)),
              ],
              onChanged: aoMudarCategoria,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Unidade>(
              initialValue: unidade,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unidade'),
              items: [
                for (final u in Unidade.values)
                  DropdownMenuItem(value: u, child: Text(u.rotulo)),
              ],
              onChanged: (v) => v == null ? null : aoMudarUnidade(v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: ocupado ? null : aoCriar,
              icon: const Icon(Icons.add),
              label: Text('Criar artigo «$nome»'),
            ),
          ],
        ),
      ),
    );
  }
}
