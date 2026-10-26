import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/modelos.dart';
import '../estatisticas/grafico_preco.dart';
import 'dialogos.dart';

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
        width: 480,
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Text(
                'Evolução do preço',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              GraficoPreco(
                registos:
                    ref.watch(registosPrecoProvider(artigo.id)).value ??
                    const [],
                lojas: lojas,
              ),
            ],
          ),
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
                    ean: r.ean,
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
