import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/compra.dart';
import '../../domain/dinheiro.dart';
import '../../domain/modelos.dart';
import 'dialogos_lista.dart';

const _outro = '__outro__';

/// Linha editável: quantidade (ou peso em kg) e preço por unidade (ou por kg).
class _Edicao {
  _Edicao(this.item, this.artigo, int? preco)
    : qtd = TextEditingController(text: qtdParaCampo(item.qtd)),
      preco = TextEditingController(
        text: preco == null ? '' : centParaCampo(preco),
      ),
      id = const Uuid().v4(),
      precoId = const Uuid().v4();

  final ItemLista item;
  final Artigo artigo;
  final TextEditingController qtd;
  final TextEditingController preco;

  /// Ids fixos enquanto o ecrã está aberto: gravar duas vezes não duplica.
  final String id;
  final String precoId;

  LinhaNova? linha() {
    final q = lerQuantidade(qtd.text, artigo.unidade);
    final p = centDeTexto(preco.text);
    if (q == null || p == null) return null;
    return LinhaNova(
      id: id,
      precoId: precoId,
      artigoId: artigo.id,
      nome: artigo.nome,
      unidade: artigo.unidade,
      precoUnitCent: p,
      quantidade: artigo.unidade == Unidade.un ? q.toInt() : null,
      pesoG: artigo.unidade == Unidade.kg ? kgParaG(q) : null,
    );
  }

  void dispose() {
    qtd.dispose();
    preco.dispose();
  }
}

class ConcluirCompraPage extends ConsumerStatefulWidget {
  const ConcluirCompraPage({super.key, this.lojaId});

  /// Loja escolhida na Lista (null = "Todas as lojas").
  final String? lojaId;

  @override
  ConsumerState<ConcluirCompraPage> createState() => _ConcluirCompraPageState();
}

class _ConcluirCompraPageState extends ConsumerState<ConcluirCompraPage> {
  final _form = GlobalKey<FormState>();
  final _compraId = const Uuid().v4();
  final _edicoes = <String, _Edicao>{};
  final _outroLocal = TextEditingController();
  final _totalTalao = TextEditingController();
  String? _lojaId;
  String? _local;
  List<String> _locais = const [];

  /// Loja cujos locais já foram pedidos (evita repetir o pedido).
  String? _locaisDe;
  DateTime _data = DateTime.now();
  bool _aGravar = false;

  @override
  void initState() {
    super.initState();
    _lojaId = widget.lojaId;
  }

  @override
  void dispose() {
    for (final e in _edicoes.values) {
      e.dispose();
    }
    _outroLocal.dispose();
    _totalTalao.dispose();
    super.dispose();
  }

  Future<void> _carregarLocais(Loja loja) async {
    final locais = await ref
        .read(comprasRepositoryProvider)
        .locaisUsados(loja.id);
    if (!mounted) return;
    setState(() {
      _locais = {...locais, ?loja.local}.toList()..sort();
      _local ??= _locais.firstOrNull ?? _outro;
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _gravar(Loja loja, List<_Edicao> edicoes) async {
    if (!_form.currentState!.validate()) return;
    final linhas = [for (final e in edicoes) e.linha()!];
    final local = _local == _outro ? _outroLocal.text.trim() : _local;
    final compra = CompraNova(
      id: _compraId,
      lojaId: loja.id,
      local: (local == null || local.isEmpty) ? null : local,
      data: _data,
      linhas: linhas,
      totalTalaoCent: centDeTexto(_totalTalao.text),
    );
    setState(() => _aGravar = true);
    try {
      await ref.read(comprasRepositoryProvider).concluir(compra);
      final online = ref.read(estadoSyncProvider).value?.online ?? true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            online
                ? 'Compra de ${formatarCent(compra.totalCent)} gravada.'
                : 'Compra de ${formatarCent(compra.totalCent)} guardada; é '
                      'enviada quando houver rede.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _aGravar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lojas = ref.watch(lojasProvider).value ?? const <Loja>[];
    final artigos = {
      for (final a in ref.watch(artigosProvider).value ?? const <Artigo>[])
        a.id: a,
    };
    final itens = ref.watch(itensListaProvider).value ?? const <ItemLista>[];
    final precos = {
      for (final p
          in ref.watch(precosAtuaisProvider).value ?? const <PrecoAtual>[])
        '${p.artigoId}|${p.lojaId}': p.precoCent,
    };
    final comprados = [
      for (final i in itens)
        if (i.comprado && i.incluido && artigos.containsKey(i.artigoId)) i,
    ];
    // Uma compra é sempre de uma só loja.
    final lojasComComprados = [
      for (final l in lojas)
        if (comprados.any((i) => i.lojaId == l.id)) l,
    ];
    final loja =
        lojasComComprados.where((l) => l.id == _lojaId).firstOrNull ??
        lojasComComprados.firstOrNull;
    final tema = Theme.of(context);

    if (loja == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Concluir compra')),
        body: const Center(
          child: Text('Não há artigos marcados como comprados.'),
        ),
      );
    }
    if (_locaisDe != loja.id) {
      _lojaId = loja.id;
      _locaisDe = loja.id;
      _local = null;
      _locais = const [];
      _carregarLocais(loja);
    }

    final edicoes = [
      for (final i in comprados.where((i) => i.lojaId == loja.id))
        _edicoes.putIfAbsent(
          '${i.lojaId}|${i.artigoId}',
          () => _Edicao(
            i,
            artigos[i.artigoId]!,
            precos['${i.artigoId}|${loja.id}'],
          ),
        ),
    ]..sort((a, b) => a.artigo.nome.compareTo(b.artigo.nome));

    final linhas = [for (final e in edicoes) e.linha()];
    final completas = linhas.every((l) => l != null);
    final rascunho = CompraNova(
      id: _compraId,
      lojaId: loja.id,
      local: null,
      data: _data,
      linhas: [for (final l in linhas) ?l],
      totalTalaoCent: centDeTexto(_totalTalao.text),
    );
    final outras = lojasComComprados.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Concluir compra')),
      body: Form(
        key: _form,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DropdownMenu<String>(
                      key: ValueKey('loja-${loja.id}'),
                      label: const Text('Loja'),
                      width: 220,
                      initialSelection: loja.id,
                      enabled: lojasComComprados.length > 1,
                      onSelected: (v) => setState(() => _lojaId = v),
                      dropdownMenuEntries: [
                        for (final l in lojasComComprados)
                          DropdownMenuEntry(value: l.id, label: l.nome),
                      ],
                    ),
                    DropdownMenu<String>(
                      key: ValueKey(
                        'local-${loja.id}-${_locais.length}-$_local',
                      ),
                      label: const Text('Local'),
                      width: 260,
                      initialSelection: _local,
                      onSelected: (v) => setState(() => _local = v),
                      dropdownMenuEntries: [
                        for (final l in _locais)
                          DropdownMenuEntry(value: l, label: l),
                        const DropdownMenuEntry(value: _outro, label: 'Outro…'),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _escolherData,
                      icon: const Icon(Icons.event),
                      label: Text('Data: ${formatarData(_data)}'),
                    ),
                  ],
                ),
                if (_local == _outro) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _outroLocal,
                    decoration: const InputDecoration(labelText: 'Outro local'),
                  ),
                ],
                if (outras > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Há comprados noutras lojas: ficam marcados para a compra '
                    'seguinte.',
                    style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                for (final e in edicoes)
                  _LinhaEdicao(edicao: e, aoMudar: () => setState(() {})),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalTalao,
                  decoration: const InputDecoration(
                    labelText: 'Total do talão (opcional)',
                    suffixText: '€',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty && centDeTexto(v!) == null
                      ? 'Valor inválido (ex.: 23,45).'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Total calculado')),
                            Text(
                              formatarCent(rascunho.totalCalculadoCent),
                              style: tema.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        if (rascunho.rever) ...[
                          const SizedBox(height: 8),
                          Text(
                            'O talão difere em ${formatarCent(rascunho.diferencaCent)}: '
                            'a compra fica marcada para rever.',
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _aGravar || !completas
                      ? null
                      : () => _gravar(loja, edicoes),
                  icon: const Icon(Icons.save),
                  label: Text(
                    'Gravar compra de ${formatarCent(rascunho.totalCent)}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinhaEdicao extends StatelessWidget {
  const _LinhaEdicao({required this.edicao, required this.aoMudar});

  final _Edicao edicao;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final kg = edicao.artigo.unidade == Unidade.kg;
    final valor = edicao.linha()?.valorCent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  edicao.artigo.nome,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(valor == null ? '—' : formatarCent(valor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: edicao.qtd,
                  decoration: InputDecoration(
                    labelText: kg ? 'Peso' : 'Quantidade',
                    suffixText: kg ? 'kg' : 'un',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: kg),
                  validator: (v) =>
                      lerQuantidade(v ?? '', edicao.artigo.unidade) == null
                      ? (kg ? 'Peso inválido' : 'Inteiro > 0')
                      : null,
                  onChanged: (_) => aoMudar(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: edicao.preco,
                  decoration: InputDecoration(
                    labelText: kg ? 'Preço por kg' : 'Preço por unidade',
                    suffixText: kg ? '€/kg' : '€',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      centDeTexto(v ?? '') == null ? 'Preço em falta' : null,
                  onChanged: (_) => aoMudar(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
