import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../domain/modelos.dart';
import '../../domain/texto.dart';
import '../../import/taloes/importar_taloes.dart';
import '../artigos/artigos_page.dart' show artigoCorresponde;

final _kg = NumberFormat('0.000', 'pt_PT');

/// Pré-visualização de uma importação de talões em PDF: um cartão por
/// talão (com o estado e as linhas) e a lista dos não reconhecidos.
class PrevisualizacaoTaloes extends StatelessWidget {
  const PrevisualizacaoTaloes({
    super.key,
    required this.taloes,
    required this.naoReconhecidos,
    required this.escolhas,
    required this.nomesArtigos,
    required this.online,
    required this.aGravar,
    required this.aoImportar,
    required this.aoCancelar,
    this.artigos = const [],
    this.categorias = const [],
    this.aoEscolher,
  });

  final List<TalaoAnalisado> taloes;
  final List<NaoReconhecido> naoReconhecidos;
  final Map<String, EscolhaArtigo> escolhas;

  /// Nome de cada artigo por id (para as linhas ligadas à mão).
  final Map<String, String> nomesArtigos;
  final bool online;
  final bool aGravar;
  final VoidCallback aoImportar;
  final VoidCallback aoCancelar;

  /// Artigos ativos (para "Ligar a um artigo…") e categorias.
  final List<Artigo> artigos;
  final List<Categoria> categorias;

  /// Escolha numa linha com artigo novo (null = desfazer). Sem isto, as
  /// linhas não têm menu.
  final void Function(String chave, EscolhaArtigo? escolha)? aoEscolher;

  int _contar(EstadoTalao e) => taloes.where((t) => t.estado == e).length;

  String get _resumo {
    String n(int c, String um, String varios) => '$c ${c == 1 ? um : varios}';
    final partes = [
      if (_contar(EstadoTalao.novo) > 0)
        n(_contar(EstadoTalao.novo), 'novo', 'novos'),
      if (_contar(EstadoTalao.aRever) > 0)
        n(_contar(EstadoTalao.aRever), 'a rever', 'a rever'),
      if (_contar(EstadoTalao.jaExiste) > 0)
        n(_contar(EstadoTalao.jaExiste), 'já importado', 'já importados'),
      if (_contar(EstadoTalao.repetidoNoLote) > 0)
        n(
          _contar(EstadoTalao.repetidoNoLote),
          'repetido neste lote',
          'repetidos neste lote',
        ),
    ];
    final resumo =
        '${n(taloes.length, 'talão', 'talões')}: ${partes.join(', ')}';
    return naoReconhecidos.isEmpty
        ? resumo
        : '$resumo · ${n(naoReconhecidos.length, 'não reconhecido', 'não reconhecidos')}';
  }

  String? _categoria(String? id) =>
      categorias.where((c) => c.id == id).firstOrNull?.nome;

  String _artigoDa(TalaoAnalisado t, LinhaAnalisada l) {
    String novo(String nome, String? categoriaId) =>
        ['Novo: $nome', ?_categoria(categoriaId)].join(' · ');
    return switch (escolhas[chaveEscolha(t.loja.id, l.linha.texto)]) {
      LigarArtigo(:final artigoId) => nomesArtigos[artigoId] ?? '—',
      NovoArtigo(:final nome, :final categoriaId) => novo(nome, categoriaId),
      null => l.artigo?.nome ?? novo(l.nomeNovo, l.categoriaSugerida),
    };
  }

  /// Menu da linha: só nas linhas com artigo novo dos talões que entram.
  Widget? _menu(BuildContext context, TalaoAnalisado t, LinhaAnalisada l) {
    final escolher = aoEscolher;
    if (escolher == null || !t.estado.importa || l.artigo != null) return null;
    final chave = chaveEscolha(t.loja.id, l.linha.texto);
    final atual = escolhas[chave];
    final nome = atual is NovoArtigo ? atual.nome : l.nomeNovo;
    final categoria = atual is NovoArtigo
        ? atual.categoriaId
        : l.categoriaSugerida;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Artigo desta linha',
      onSelected: (acao) async {
        switch (acao) {
          case 'ligar':
            final a = await showDialog<Artigo>(
              context: context,
              builder: (_) => _DialogoLigar(artigos: artigos),
            );
            if (a != null) escolher(chave, LigarArtigo(a.id));
          case 'nome':
            final n = await showDialog<String>(
              context: context,
              builder: (_) => _DialogoNome(nome: nome),
            );
            if (n != null && n.trim().isNotEmpty) {
              escolher(
                chave,
                NovoArtigo(nome: n.trim(), categoriaId: categoria),
              );
            }
          case 'categoria':
            final c = await showDialog<(String?,)>(
              context: context,
              builder: (_) =>
                  _DialogoCategoria(categorias: categorias, atual: categoria),
            );
            if (c != null) {
              escolher(chave, NovoArtigo(nome: nome, categoriaId: c.$1));
            }
          case 'desfazer':
            escolher(chave, null);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'ligar', child: Text('Ligar a um artigo…')),
        const PopupMenuItem(value: 'nome', child: Text('Mudar o nome…')),
        const PopupMenuItem(value: 'categoria', child: Text('Categoria…')),
        if (atual != null)
          const PopupMenuItem(value: 'desfazer', child: Text('Desfazer')),
      ],
    );
  }

  String _quantidade(LinhaAnalisada l) => l.linha.pesoG != null
      ? '${_kg.format(l.linha.pesoG! / 1000)} kg'
      : '${l.linha.quantidade ?? 1} un';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aImportar = taloes.where((t) => t.estado.importa).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Talões (PDF)', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_resumo),
            const SizedBox(height: 12),
            for (final t in taloes) _talao(context, t),
            if (naoReconhecidos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Não reconhecidos', style: tema.textTheme.titleSmall),
              for (final n in naoReconhecidos)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${n.ficheiro}: ${n.motivo}',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
            ],
            if (!online) ...[
              const SizedBox(height: 12),
              Text(
                'Sem rede: a importação de talões precisa do servidor.',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: aGravar ? null : aoCancelar,
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: aImportar == 0 || !online || aGravar
                      ? null
                      : aoImportar,
                  child: Text(
                    'Importar $aImportar ${aImportar == 1 ? 'talão' : 'talões'}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _talao(BuildContext context, TalaoAnalisado t) {
    final tema = Theme.of(context);
    final cor = switch (t.estado) {
      EstadoTalao.novo => tema.colorScheme.primary,
      EstadoTalao.aRever => tema.colorScheme.error,
      _ => tema.colorScheme.onSurfaceVariant,
    };
    return ExpansionTile(
      key: PageStorageKey('talao-${t.ficheiro}'),
      initiallyExpanded: t.estado.importa,
      tilePadding: EdgeInsets.zero,
      title: Text(t.talao.local ?? t.loja.nome),
      subtitle: Text(
        '${formatarData(t.talao.data)} · ${formatarCent(t.talao.totalCent)} · '
        '${t.estado.rotulo}',
        style: TextStyle(color: cor),
      ),
      children: [
        for (final l in t.linhas)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l.linha.texto),
            subtitle: Text('${_quantidade(l)} · ${_artigoDa(t, l)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text(formatarCent(l.pagoCent)), ?_menu(context, t, l)],
            ),
          ),
      ],
    );
  }
}

/// Escolher um artigo existente, com pesquisa sem acentos (nome ou EAN).
class _DialogoLigar extends StatefulWidget {
  const _DialogoLigar({required this.artigos});
  final List<Artigo> artigos;

  @override
  State<_DialogoLigar> createState() => _DialogoLigarState();
}

class _DialogoLigarState extends State<_DialogoLigar> {
  String _termo = '';

  @override
  Widget build(BuildContext context) {
    final termo = normalizar(_termo.trim());
    final achados = [
      for (final a in widget.artigos)
        if (a.ativo && artigoCorresponde(a, termo)) a,
    ]..sort((a, b) => a.nome.compareTo(b.nome));
    return AlertDialog(
      title: const Text('Ligar a um artigo'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pesquisar',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _termo = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final a in achados.take(50))
                    ListTile(
                      dense: true,
                      title: Text(a.nome),
                      onTap: () => Navigator.pop(context, a),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _DialogoNome extends StatefulWidget {
  const _DialogoNome({required this.nome});
  final String nome;

  @override
  State<_DialogoNome> createState() => _DialogoNomeState();
}

class _DialogoNomeState extends State<_DialogoNome> {
  late final _campo = TextEditingController(text: widget.nome);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome do artigo novo'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _campo,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nome'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _campo.text),
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Devolve `(categoriaId,)`; `(null,)` = sem categoria; null = cancelado.
class _DialogoCategoria extends StatefulWidget {
  const _DialogoCategoria({required this.categorias, required this.atual});
  final List<Categoria> categorias;
  final String? atual;

  @override
  State<_DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends State<_DialogoCategoria> {
  late String? _id = widget.atual;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Categoria do artigo novo'),
    content: SizedBox(
      width: 420,
      child: DropdownButtonFormField<String?>(
        initialValue: _id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Categoria'),
        items: [
          const DropdownMenuItem(child: Text('Sem categoria')),
          for (final c in widget.categorias)
            DropdownMenuItem(value: c.id, child: Text(c.nome)),
        ],
        onChanged: (v) => setState(() => _id = v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, (_id,)),
        child: const Text('Guardar'),
      ),
    ],
  );
}
