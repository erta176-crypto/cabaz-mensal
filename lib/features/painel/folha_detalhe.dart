import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../data/repositorios.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../artigos/ver_artigo.dart';

/// Folha com os artigos de uma barra do Painel (Fase 14, D5 e D6).
/// [painelDaCache]: o Painel está a mostrar a última resposta guardada.
Future<void> abrirDetalhePainel(
  BuildContext context, {
  required String titulo,
  required BarraPainel barra,
  required bool painelDaCache,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _FolhaDetalhe(
      titulo: titulo,
      barra: barra,
      painelDaCache: painelDaCache,
    ),
  ),
);

class _FolhaDetalhe extends ConsumerWidget {
  const _FolhaDetalhe({
    required this.titulo,
    required this.barra,
    required this.painelDaCache,
  });

  final String titulo;
  final BarraPainel barra;
  final bool painelDaCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final detalhe = ref.watch(detalhePainelProvider(barra));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(titulo, style: tema.textTheme.titleLarge),
          ),
        ),
        if (painelDaCache)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'O Painel está desatualizado; esta lista é de agora.',
              style: tema.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: switch (detalhe) {
            AsyncData(:final value) => _Lista(detalhe: value),
            AsyncError(:final error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is ErroDados ? error.mensagem : '$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.detalhe});

  final DetalhePainel detalhe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artigos = {
      for (final a in ref.watch(artigosProvider).value ?? const <Artigo>[])
        a.id: a,
    };
    String subtitulo(ArtigoDetalhe a) => [
      a.porPeso ? formatarKg(a.pesoG) : '${a.quantidade} un',
      '${a.nCompras} ${a.nCompras == 1 ? 'compra' : 'compras'}',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final a in detalhe.artigos)
          ListTile(
            title: Text(artigos[a.artigoId]?.nome ?? 'Artigo apagado'),
            subtitle: Text(subtitulo(a)),
            trailing: Text(formatarCent(a.totalCent)),
            onTap: artigos[a.artigoId] == null
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        DialogoVerArtigo(artigo: artigos[a.artigoId]!),
                  ),
          ),
        if (detalhe.semArtigoCent != 0)
          ListTile(
            title: const Text('Linhas sem artigo'),
            trailing: Text(formatarCent(detalhe.semArtigoCent)),
          ),
        if (detalhe.diferencaCent != 0)
          ListTile(
            title: const Text('Diferença do total das compras'),
            subtitle: const Text('Compras sem linhas ou que não batem.'),
            trailing: Text(formatarCent(detalhe.diferencaCent)),
          ),
        const Divider(),
        ListTile(
          title: const Text(
            'Total',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            formatarCent(detalhe.totalCent),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
