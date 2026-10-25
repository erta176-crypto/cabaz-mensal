import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/dinheiro.dart';
import '../../domain/ean.dart';
import '../../domain/modelos.dart';

class ResultadoArtigo {
  const ResultadoArtigo({
    required this.nome,
    required this.categoriaId,
    required this.unidade,
    required this.ean,
    required this.precosCent,
  });

  final String nome;
  final String? categoriaId;
  final Unidade unidade;
  final String? ean;
  final Map<String, int?> precosCent;
}

/// Criar ou editar um artigo: nome, categoria, unidade, código de barras e
/// preço por loja.
class DialogoArtigo extends ConsumerStatefulWidget {
  const DialogoArtigo({
    super.key,
    this.artigo,
    required this.categorias,
    required this.lojas,
    required this.precosAtuais,
  });

  final Artigo? artigo;
  final List<Categoria> categorias;
  final List<Loja> lojas;

  /// Preço atual por id de loja.
  final Map<String, int> precosAtuais;

  @override
  ConsumerState<DialogoArtigo> createState() => _DialogoArtigoState();
}

class _DialogoArtigoState extends ConsumerState<DialogoArtigo> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.artigo?.nome);
  late final _ean = TextEditingController(text: widget.artigo?.ean);
  late String? _categoriaId = widget.artigo?.categoriaId;
  late Unidade _unidade = widget.artigo?.unidade ?? Unidade.un;
  late final _precos = {
    for (final l in widget.lojas)
      l.id: TextEditingController(
        text: widget.precosAtuais[l.id] == null
            ? ''
            : centParaCampo(widget.precosAtuais[l.id]!),
      ),
  };

  @override
  void dispose() {
    _nome.dispose();
    _ean.dispose();
    for (final c in _precos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      ResultadoArtigo(
        nome: _nome.text.trim(),
        categoriaId: _categoriaId,
        unidade: _unidade,
        ean: normalizarEan(_ean.text),
        precosCent: {
          for (final MapEntry(:key, :value) in _precos.entries)
            key: centDeTexto(value.text),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sufixo = _unidade == Unidade.kg ? '€/kg' : '€';
    // Sem índice único no servidor (sincronização sem rede): só avisa.
    // O watch é feito sempre, para os artigos já estarem cá quando se escreve.
    final artigos = ref.watch(artigosProvider).value ?? const <Artigo>[];
    final ean = normalizarEan(_ean.text);
    final repetido = ean == null
        ? null
        : artigos
              .where((a) => a.ean == ean && a.id != widget.artigo?.id)
              .firstOrNull;
    return AlertDialog(
      title: Text(widget.artigo == null ? 'Novo artigo' : 'Editar artigo'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nome,
                  autofocus: widget.artigo == null,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escreve um nome.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem categoria'),
                    ),
                    for (final c in widget.categorias)
                      DropdownMenuItem(value: c.id, child: Text(c.nome)),
                  ],
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Unidade>(
                  initialValue: _unidade,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: [
                    for (final u in Unidade.values)
                      DropdownMenuItem(value: u, child: Text(u.rotulo)),
                  ],
                  onChanged: (v) => setState(() => _unidade = v ?? _unidade),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ean,
                  decoration: InputDecoration(
                    labelText: 'Código de barras (opcional)',
                    helperText: repetido == null
                        ? null
                        : 'Este código já está no artigo "${repetido.nome}".',
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty && normalizarEan(v!) == null
                      ? 'Código inválido (8, 12, 13 ou 14 dígitos).'
                      : null,
                ),
                for (final l in widget.lojas) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _precos[l.id],
                    decoration: InputDecoration(
                      labelText: 'Preço no ${l.nome}',
                      suffixText: sufixo,
                      hintText: 'sem preço',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isNotEmpty && centDeTexto(v!) == null
                        ? 'Valor inválido (ex.: 1,29).'
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Criar ou editar uma categoria (nome e ordem).
class DialogoCategoria extends StatefulWidget {
  const DialogoCategoria({super.key, this.categoria, required this.ordemNova});

  final Categoria? categoria;
  final int ordemNova;

  @override
  State<DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends State<DialogoCategoria> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.categoria?.nome);
  late final _ordem = TextEditingController(
    text: '${widget.categoria?.ordem ?? widget.ordemNova}',
  );

  @override
  void dispose() {
    _nome.dispose();
    _ordem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.categoria == null ? 'Nova categoria' : 'Editar categoria',
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nome,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escreve um nome.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ordem,
                decoration: const InputDecoration(labelText: 'Ordem na lista'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Número inteiro.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, (
              nome: _nome.text.trim(),
              ordem: int.parse(_ordem.text),
            ));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Ao eliminar uma categoria com artigos, pergunta para onde os mover.
/// Devolve `(destino: id ou null)`, ou null se cancelado.
class DialogoMoverArtigos extends StatefulWidget {
  const DialogoMoverArtigos({
    super.key,
    required this.categoria,
    required this.nArtigos,
    required this.outras,
  });

  final Categoria categoria;
  final int nArtigos;
  final List<Categoria> outras;

  @override
  State<DialogoMoverArtigos> createState() => _DialogoMoverArtigosState();
}

class _DialogoMoverArtigosState extends State<DialogoMoverArtigos> {
  String? _destino;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Eliminar "${widget.categoria.nome}"?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta categoria tem ${widget.nArtigos} '
              '${widget.nArtigos == 1 ? 'artigo' : 'artigos'}. '
              'Para onde os queres mover?',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _destino,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mover para'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sem categoria'),
                ),
                for (final c in widget.outras)
                  DropdownMenuItem(value: c.id, child: Text(c.nome)),
              ],
              onChanged: (v) => setState(() => _destino = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (destino: _destino)),
          child: const Text('Mover e eliminar'),
        ),
      ],
    );
  }
}

/// Cores disponíveis para as lojas (menu de seleção).
const coresLoja = {
  '#2a78d6': 'Azul',
  '#eb6834': 'Laranja',
  '#1baf7a': 'Verde',
  '#d64545': 'Vermelho',
  '#7b5cd6': 'Roxo',
  '#e0a92b': 'Amarelo',
  '#b4532a': 'Terracota',
  '#7a7a7a': 'Cinzento',
};

/// Criar ou editar uma loja: nome, cadeia, local e cor.
class DialogoLoja extends StatefulWidget {
  const DialogoLoja({super.key, this.loja});

  final Loja? loja;

  @override
  State<DialogoLoja> createState() => _DialogoLojaState();
}

class _DialogoLojaState extends State<DialogoLoja> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.loja?.nome);
  late final _cadeia = TextEditingController(text: widget.loja?.cadeia);
  late final _local = TextEditingController(text: widget.loja?.local);
  late String _cor = widget.loja?.cor?.toLowerCase() ?? coresLoja.keys.first;

  @override
  void dispose() {
    _nome.dispose();
    _cadeia.dispose();
    _local.dispose();
    super.dispose();
  }

  String? _texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final cores = {
      ...coresLoja,
      if (!coresLoja.containsKey(_cor)) _cor: 'Atual',
    };
    return AlertDialog(
      title: Text(widget.loja == null ? 'Nova loja' : 'Editar loja'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nome,
                  autofocus: widget.loja == null,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escreve um nome.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cadeia,
                  decoration: const InputDecoration(
                    labelText: 'Cadeia',
                    hintText: 'ex.: Lidl',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _local,
                  decoration: const InputDecoration(
                    labelText: 'Local',
                    hintText: 'ex.: Entroncamento',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _cor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  items: [
                    for (final MapEntry(key: hex, value: nome) in cores.entries)
                      DropdownMenuItem(
                        value: hex,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: Color(
                                0xFF000000 |
                                    int.parse(hex.substring(1), radix: 16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(nome),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cor = v ?? _cor),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final nome = _nome.text.trim();
            final base = widget.loja;
            Navigator.pop(
              context,
              Loja(
                id: base?.id ?? const Uuid().v4(),
                slug: base?.slug ?? '',
                nome: nome,
                cadeia: _texto(_cadeia) ?? nome,
                local: _texto(_local),
                cor: _cor,
                arquivada: base?.arquivada ?? false,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
