import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/modelos.dart';
import '../artigos/dialogos.dart';

/// Lê uma quantidade escrita pelo utilizador ("1,3", "2"). Nos artigos à
/// unidade só aceita inteiros.
num? lerQuantidade(String texto, Unidade unidade) {
  final v = num.tryParse(texto.trim().replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  if (unidade == Unidade.un) return v == v.roundToDouble() ? v.toInt() : null;
  return (v * 1000).round() / 1000;
}

String qtdParaCampo(num qtd) => qtd == qtd.roundToDouble()
    ? qtd.toInt().toString()
    : qtd.toString().replaceAll('.', ',');

class DialogoQuantidade extends StatefulWidget {
  const DialogoQuantidade({
    super.key,
    required this.titulo,
    required this.artigo,
    required this.inicial,
  });

  final String titulo;
  final Artigo artigo;
  final num inicial;

  @override
  State<DialogoQuantidade> createState() => _DialogoQuantidadeState();
}

class _DialogoQuantidadeState extends State<DialogoQuantidade> {
  late final _texto = TextEditingController(text: qtdParaCampo(widget.inicial));
  String? _erro;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _guardar() {
    final v = lerQuantidade(_texto.text, widget.artigo.unidade);
    if (v == null) {
      setState(
        () => _erro = widget.artigo.unidade == Unidade.un
            ? 'Número inteiro maior que zero.'
            : 'Número maior que zero (ex.: 1,3).',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.artigo.nome),
          const SizedBox(height: 16),
          TextField(
            controller: _texto,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.artigo.unidade == Unidade.kg,
            ),
            decoration: InputDecoration(
              labelText: 'Quantidade',
              suffixText: widget.artigo.unidade.codigo,
              errorText: _erro,
            ),
            onSubmitted: (_) => _guardar(),
          ),
        ],
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

class DialogoVerArtigo extends ConsumerWidget {
  const DialogoVerArtigo({super.key, required this.artigo});

  final Artigo artigo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lojas = ref.watch(lojasProvider).value ?? const <Loja>[];
    final categorias =
        ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final precos = {
      for (final p
          in ref.watch(precosAtuaisProvider).value ?? const <PrecoAtual>[])
        if (p.artigoId == artigo.id) p.lojaId: p,
    };
    final categoria = categorias
        .where((c) => c.id == artigo.categoriaId)
        .firstOrNull;
    final porKg = artigo.unidade == Unidade.kg ? '/kg' : '';

    return AlertDialog(
      title: Text(artigo.nome),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categoria: ${categoria?.nome ?? 'Sem categoria'}'),
            Text('Unidade: ${artigo.unidade.rotulo}'),
            const SizedBox(height: 12),
            for (final l in lojas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.nome),
                subtitle: precos[l.id] == null
                    ? null
                    : Text('em ${formatarData(precos[l.id]!.data)}'),
                trailing: Text(
                  precos[l.id] == null
                      ? 'sem preço'
                      : '${formatarCent(precos[l.id]!.precoCent)}$porKg',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final r = await showDialog<ResultadoArtigo>(
              context: context,
              builder: (_) => DialogoArtigo(
                artigo: artigo,
                categorias: categorias,
                lojas: lojas.where((l) => !l.arquivada).toList(),
                precosAtuais: {
                  for (final MapEntry(:key, :value) in precos.entries)
                    key: value.precoCent,
                },
              ),
            );
            if (r == null) return;
            await ref
                .read(artigosRepositoryProvider)
                .guardar(
                  Artigo(
                    id: artigo.id,
                    nome: r.nome,
                    categoriaId: r.categoriaId,
                    unidade: r.unidade,
                    ativo: artigo.ativo,
                  ),
                  precosCent: r.precosCent,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Editar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
