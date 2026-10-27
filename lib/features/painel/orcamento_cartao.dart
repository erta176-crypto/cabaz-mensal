import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/dinheiro.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../../domain/orcamento.dart';

final _nomeMes = DateFormat('MMMM', 'pt_PT');

/// Texto de uma linha do orçamento: "420,00 € de 500,00 € · faltam 80,00 €".
/// O nível também vai em texto, não só na cor.
String textoOrcamento(LinhaOrcamento l) {
  final resto = l.faltaCent >= 0
      ? 'faltam ${formatarCent(l.faltaCent)}'
      : 'passou ${formatarCent(-l.faltaCent)}';
  return '${formatarCent(l.gastoCent)} de ${formatarCent(l.orcamentoCent)} · '
      '$resto${l.nivel == NivelOrcamento.quase ? ' · quase no limite' : ''}';
}

Color corDoNivel(NivelOrcamento n, ColorScheme e) => switch (n) {
  NivelOrcamento.ok => e.primary,
  NivelOrcamento.quase => e.tertiary,
  NivelOrcamento.passou => e.error,
};

/// Cartão "Orçamento" do Painel (período "Este mês", todas as lojas).
class OrcamentoCartao extends ConsumerWidget {
  const OrcamentoCartao({super.key, required this.gasto, required this.hoje});

  /// Gasto do mês atual (resultado do Painel).
  final DadosPainel gasto;
  final DateTime hoje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final mes = DateTime(hoje.year, hoje.month);
    final anterior = DateTime(hoje.year, hoje.month - 1);
    final todos = ref.watch(orcamentosProvider).value ?? const <Orcamento>[];
    final doMes = [
      for (final o in todos)
        if (o.mes == mes) o,
    ];
    final temAnterior = todos.any((o) => o.mes == anterior);
    final categorias =
        ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final nomes = {for (final c in categorias) c.id: c.nome};

    Future<void> editar() => showDialog<void>(
      context: context,
      builder: (_) =>
          DialogoOrcamento(mes: mes, doMes: doMes, categorias: categorias),
    );

    final Widget corpo;
    if (doMes.isEmpty) {
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sem orçamento para ${_nomeMes.format(mes)}.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: editar,
                child: const Text('Definir orçamento'),
              ),
              if (temAnterior)
                OutlinedButton(
                  onPressed: () => ref
                      .read(orcamentosRepositoryProvider)
                      .copiar(anterior, mes),
                  child: Text('Copiar de ${_nomeMes.format(anterior)}'),
                ),
            ],
          ),
        ],
      );
    } else {
      final r = compararOrcamento(doMes, gasto);
      Widget linha(String titulo, LinhaOrcamento l) {
        final cor = corDoNivel(l.nivel, tema.colorScheme);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: tema.textTheme.bodyLarge),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: l.orcamentoCent <= 0
                    ? 1
                    : min(l.gastoCent / l.orcamentoCent, 1),
                color: cor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                textoOrcamento(l),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: l.nivel == NivelOrcamento.passou
                      ? tema.colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
        );
      }

      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.total != null) linha('Total do mês', r.total!),
          for (final c in r.categorias)
            linha(nomes[c.categoriaId] ?? 'Categoria apagada', c),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Orçamento', style: tema.textTheme.titleMedium),
                ),
                if (doMes.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Ações do orçamento',
                    onSelected: (_) => editar(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar orçamento'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            corpo,
          ],
        ),
      ),
    );
  }
}

/// Diálogo "Editar orçamento": total do mês e um campo por categoria
/// (vazio = sem orçamento). Só grava o que mudou.
class DialogoOrcamento extends ConsumerStatefulWidget {
  const DialogoOrcamento({
    super.key,
    required this.mes,
    required this.doMes,
    required this.categorias,
  });

  final DateTime mes;
  final List<Orcamento> doMes;
  final List<Categoria> categorias;

  @override
  ConsumerState<DialogoOrcamento> createState() => _DialogoOrcamentoState();
}

class _DialogoOrcamentoState extends ConsumerState<DialogoOrcamento> {
  late final Map<String?, int> _atuais = {
    for (final o in widget.doMes) o.categoriaId: o.valorCent,
  };
  late final Map<String?, TextEditingController> _campos = {
    for (final id in [null, ...widget.categorias.map((c) => c.id)])
      id: TextEditingController(
        text: _atuais[id] == null ? '' : centParaCampo(_atuais[id]!),
      ),
  };
  final _invalidos = <String?>{};

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final novos = <String?, int?>{};
    final invalidos = <String?>{};
    for (final MapEntry(key: id, value: c) in _campos.entries) {
      final texto = c.text.trim();
      final valor = centDeTexto(texto);
      if (texto.isNotEmpty && valor == null) invalidos.add(id);
      novos[id] = valor;
    }
    if (invalidos.isNotEmpty) {
      setState(
        () => _invalidos
          ..clear()
          ..addAll(invalidos),
      );
      return;
    }
    final navegador = Navigator.of(context);
    final repo = ref.read(orcamentosRepositoryProvider);
    for (final MapEntry(key: id, value: valor) in novos.entries) {
      if (valor != _atuais[id]) await repo.definir(widget.mes, id, valor);
    }
    navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget campo(String? id, String rotulo) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _campos[id],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '$rotulo (€)',
          errorText: _invalidos.contains(id) ? 'Valor inválido' : null,
        ),
      ),
    );

    return AlertDialog(
      title: const Text('Editar orçamento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          // Espaço para o rótulo do primeiro campo, que flutua acima da caixa.
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              campo(null, 'Total do mês'),
              const Divider(height: 24),
              Text(
                'Por categoria (opcional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              for (final c in widget.categorias) campo(c.id, c.nome),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
