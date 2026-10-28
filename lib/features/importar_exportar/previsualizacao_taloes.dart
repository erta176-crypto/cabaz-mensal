import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../domain/dinheiro.dart';
import '../../domain/modelos.dart';
import '../../domain/texto.dart';
import '../../import/taloes/importar_taloes.dart';
import '../../import/taloes/talao.dart';
import '../artigos/artigos_page.dart' show artigoCorresponde;

final _kg = NumberFormat('0.000', 'pt_PT');

/// Pré-visualização de uma importação de talões (PDF ou fotografia): um
/// cartão por talão (com o estado e as linhas) e a lista dos não
/// reconhecidos. Com [aoEditar], as linhas, o total e a data corrigem-se.
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
    this.aoEditar,
    this.fotos = const {},
    this.titulo = 'Talões (PDF)',
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

  /// Talão corrigido (linhas, linhas por reconhecer, total ou data).
  final void Function(String ficheiro, TalaoLido talao)? aoEditar;

  /// Caminho da fotografia de cada talão (para "Ver fotografia").
  final Map<String, String> fotos;
  final String titulo;

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

  /// Menu da linha: o artigo (só nas linhas com artigo novo dos talões que
  /// entram) e, com [aoEditar], editar e apagar a linha.
  Widget? _menu(
    BuildContext context,
    TalaoAnalisado t,
    int i,
    LinhaAnalisada l,
  ) {
    final escolher = aoEscolher;
    final editar = aoEditar;
    final doArtigo = escolher != null && t.estado.importa && l.artigo == null;
    if (!doArtigo && editar == null) return null;
    final chave = chaveEscolha(t.loja.id, l.linha.texto);
    final atual = escolhas[chave];
    final nome = atual is NovoArtigo ? atual.nome : l.nomeNovo;
    final categoria = atual is NovoArtigo
        ? atual.categoriaId
        : l.categoriaSugerida;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Ações da linha',
      onSelected: (acao) async {
        switch (acao) {
          case 'ligar':
            final a = await showDialog<Artigo>(
              context: context,
              builder: (_) => _DialogoLigar(artigos: artigos),
            );
            if (a != null) escolher!(chave, LigarArtigo(a.id));
          case 'nome':
            final n = await showDialog<String>(
              context: context,
              builder: (_) => _DialogoNome(nome: nome),
            );
            if (n != null && n.trim().isNotEmpty) {
              escolher!(
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
              escolher!(chave, NovoArtigo(nome: nome, categoriaId: c.$1));
            }
          case 'desfazer':
            escolher!(chave, null);
          case 'editar':
            final nova = await showDialog<LinhaTalao>(
              context: context,
              builder: (_) => DialogoLinha(linha: l.linha),
            );
            if (nova != null) {
              editar!(
                t.ficheiro,
                t.talao.copyWith(linhas: [...t.talao.linhas]..[i] = nova),
              );
            }
          case 'apagar':
            editar!(
              t.ficheiro,
              t.talao.copyWith(linhas: [...t.talao.linhas]..removeAt(i)),
            );
        }
      },
      itemBuilder: (_) => [
        if (doArtigo) ...[
          const PopupMenuItem(
            value: 'ligar',
            child: Text('Ligar a um artigo…'),
          ),
          const PopupMenuItem(value: 'nome', child: Text('Mudar o nome…')),
          const PopupMenuItem(value: 'categoria', child: Text('Categoria…')),
          if (atual != null)
            const PopupMenuItem(value: 'desfazer', child: Text('Desfazer')),
        ],
        if (editar != null) ...[
          const PopupMenuItem(value: 'editar', child: Text('Editar linha…')),
          const PopupMenuItem(value: 'apagar', child: Text('Apagar linha')),
        ],
      ],
    );
  }

  /// Correções do talão: linhas por reconhecer, acrescentar linha, total e
  /// data, ver a fotografia.
  List<Widget> _correcoes(BuildContext context, TalaoAnalisado t) {
    final editar = aoEditar;
    if (editar == null) return const [];
    final tema = Theme.of(context);
    final talao = t.talao;
    final foto = fotos[t.ficheiro];

    Future<void> acrescentar({
      String? texto,
      int? valorCent,
      int? estranha,
    }) async {
      final nova = await showDialog<LinhaTalao>(
        context: context,
        builder: (_) => DialogoLinha(texto: texto, valorCent: valorCent),
      );
      if (nova == null) return;
      editar(
        t.ficheiro,
        talao.copyWith(
          linhas: [...talao.linhas, nova],
          naoReconhecidas: estranha == null
              ? null
              : ([...talao.naoReconhecidas]..removeAt(estranha)),
        ),
      );
    }

    return [
      if (!talao.bate)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Soma das linhas ${formatarCent(talao.somaCent)}; '
            'total ${formatarCent(talao.totalCent)}.',
            style: TextStyle(color: tema.colorScheme.error),
          ),
        ),
      for (final (i, e) in talao.naoReconhecidas.indexed)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.help_outline, color: tema.colorScheme.error),
          title: Text(e),
          subtitle: const Text(
            'Por reconhecer: toca para acrescentar como linha',
          ),
          onTap: () {
            final (:texto, :valorCent) = separarValor(e);
            acrescentar(texto: texto, valorCent: valorCent, estranha: i);
          },
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Ignorar',
            onPressed: () => editar(
              t.ficheiro,
              talao.copyWith(
                naoReconhecidas: [...talao.naoReconhecidas]..removeAt(i),
              ),
            ),
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: acrescentar,
            icon: const Icon(Icons.add),
            label: const Text('Acrescentar linha'),
          ),
          TextButton.icon(
            onPressed: () async {
              final r = await showDialog<(int, DateTime)>(
                context: context,
                builder: (_) =>
                    DialogoTotal(totalCent: talao.totalCent, data: talao.data),
              );
              if (r != null) {
                editar(t.ficheiro, talao.copyWith(totalCent: r.$1, data: r.$2));
              }
            },
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Corrigir total e data'),
          ),
          if (foto != null)
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _VerFotografia(caminho: foto),
              ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Ver fotografia'),
            ),
        ],
      ),
    ];
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
            Text(titulo, style: tema.textTheme.titleLarge),
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
        for (final (i, l) in t.linhas.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l.linha.texto),
            subtitle: Text('${_quantidade(l)} · ${_artigoDa(t, l)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatarCent(l.pagoCent)),
                ?_menu(context, t, i, l),
              ],
            ),
          ),
        ..._correcoes(context, t),
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

/// Editar ou acrescentar uma linha do talão. Devolve a linha nova.
class DialogoLinha extends StatefulWidget {
  const DialogoLinha({super.key, this.linha, this.texto, this.valorCent});

  /// A linha a editar; null = acrescentar.
  final LinhaTalao? linha;

  /// Para acrescentar a partir de uma linha por reconhecer.
  final String? texto;
  final int? valorCent;

  @override
  State<DialogoLinha> createState() => _DialogoLinhaState();
}

class _DialogoLinhaState extends State<DialogoLinha> {
  late final _l = widget.linha;
  late bool _peso = _l?.pesoG != null;
  late final _texto = TextEditingController(text: _l?.texto ?? widget.texto);
  late final _medida = TextEditingController(
    text: _l?.pesoG != null
        ? _kg.format(_l!.pesoG! / 1000)
        : '${_l?.quantidade ?? 1}',
  );
  late final _valor = TextEditingController(
    text: switch (_l?.brutoCent ?? widget.valorCent) {
      final v? => centParaCampo(v),
      null => '',
    },
  );
  late final _desconto = TextEditingController(
    text: (_l?.descontoCent ?? 0) > 0 ? centParaCampo(_l!.descontoCent) : '',
  );
  bool _validar = false;

  @override
  void dispose() {
    for (final c in [_texto, _medida, _valor, _desconto]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _quantidade {
    final q = int.tryParse(_medida.text.trim());
    return q != null && q > 0 ? q : null;
  }

  int? get _pesoG => gDeTexto(_medida.text);
  int? get _bruto => centDeTexto(_valor.text);

  /// Vazio = sem desconto.
  int? get _descontoCent =>
      _desconto.text.trim().isEmpty ? 0 : centDeTexto(_desconto.text);

  void _guardar() {
    final quantidade = _peso ? null : _quantidade;
    final pesoG = _peso ? _pesoG : null;
    final bruto = _bruto;
    final desconto = _descontoCent;
    if (_texto.text.trim().isEmpty ||
        (quantidade == null && pesoG == null) ||
        bruto == null ||
        desconto == null ||
        desconto > bruto) {
      setState(() => _validar = true);
      return;
    }
    Navigator.pop(
      context,
      LinhaTalao(
        texto: _texto.text.trim(),
        quantidade: quantidade,
        pesoG: pesoG,
        precoUnitCent: precoUnitarioCent(
          brutoCent: bruto,
          quantidade: quantidade,
          pesoG: pesoG,
        )!,
        brutoCent: bruto,
        descontoCent: desconto,
        seccao: _l?.seccao,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? erro(bool mau, String texto) => _validar && mau ? texto : null;
    final medidaMa = _peso ? _pesoG == null : _quantidade == null;
    final desconto = _descontoCent;
    final descontoMau = desconto == null || desconto > (_bruto ?? 0);
    TextInputType numero() =>
        const TextInputType.numberWithOptions(decimal: true);
    return _dialogoCorrecao(
      context,
      titulo: widget.linha == null ? 'Acrescentar linha' : 'Editar linha',
      aoGuardar: _guardar,
      campos: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _texto,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Texto do talão',
              errorText: erro(_texto.text.trim().isEmpty, 'Obrigatório'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            initialValue: _peso,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Medida'),
            items: const [
              DropdownMenuItem(value: false, child: Text('Unidades')),
              DropdownMenuItem(value: true, child: Text('Peso (kg)')),
            ],
            onChanged: (v) => setState(() => _peso = v ?? _peso),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medida,
            keyboardType: numero(),
            decoration: InputDecoration(
              labelText: _peso ? 'Peso (kg)' : 'Quantidade',
              errorText: erro(
                medidaMa,
                _peso ? 'Peso inválido' : 'Quantidade inválida',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valor,
            keyboardType: numero(),
            decoration: InputDecoration(
              labelText: 'Valor (€)',
              errorText: erro(_bruto == null, 'Valor inválido'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desconto,
            keyboardType: numero(),
            decoration: InputDecoration(
              labelText: 'Desconto (€)',
              errorText: erro(descontoMau, 'Desconto inválido'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corrigir o total e a data de um talão. Devolve `(totalCent, data)`.
class DialogoTotal extends StatefulWidget {
  const DialogoTotal({super.key, required this.totalCent, required this.data});
  final int totalCent;
  final DateTime data;

  @override
  State<DialogoTotal> createState() => _DialogoTotalState();
}

class _DialogoTotalState extends State<DialogoTotal> {
  late final _total = TextEditingController(
    text: centParaCampo(widget.totalCent),
  );
  late DateTime _data = widget.data;
  bool _validar = false;

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  void _guardar() {
    final total = centDeTexto(_total.text);
    if (total == null) {
      setState(() => _validar = true);
    } else {
      Navigator.pop(context, (total, _data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _dialogoCorrecao(
      context,
      titulo: 'Corrigir total e data',
      aoGuardar: _guardar,
      campos: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _total,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Total pago (€)',
              errorText: _validar && centDeTexto(_total.text) == null
                  ? 'Valor inválido'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _data,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d != null) setState(() => _data = d);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text('Data: ${formatarData(_data)}'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de correção com Cancelar e Guardar. Deitado e com o teclado
/// aberto sobram ≈110 dp: rola tudo (título, campos e botões) e as margens
/// de cima e de baixo são pequenas.
Widget _dialogoCorrecao(
  BuildContext context, {
  required String titulo,
  required Widget campos,
  required VoidCallback aoGuardar,
}) => AlertDialog(
  scrollable: true,
  insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
  title: Text(titulo),
  content: SizedBox(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        campos,
        const SizedBox(height: 24),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(onPressed: aoGuardar, child: const Text('Guardar')),
          ],
        ),
      ],
    ),
  ),
);

/// A fotografia do talão em ecrã inteiro, com zoom.
class _VerFotografia extends StatelessWidget {
  const _VerFotografia({required this.caminho});
  final String caminho;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 6,
            child: Image.file(
              File(caminho),
              semanticLabel: 'Fotografia do talão',
              errorBuilder: (_, _, _) => const Center(
                child: Text('Não foi possível abrir a fotografia.'),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton.filledTonal(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    ),
  );
}
