import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../artigos/ver_artigo.dart';

final _kg = NumberFormat('0.000', 'pt_PT');

const avisoRever = 'A soma das linhas não bate com o total';

String origemCompra(String origem) => switch (origem) {
  'talao' => 'Talão',
  'manual' => 'Registada à mão',
  'importacao' => 'Importada',
  'lista' => 'Concluir compra',
  _ => origem,
};

/// Detalhe de uma compra: cabeçalho e linhas do talão (só com rede).
class DetalheCompra extends ConsumerWidget {
  const DetalheCompra({super.key, required this.compra});

  final CompraResumo compra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final loja = (ref.watch(lojasProvider).value ?? const <Loja>[])
        .where((l) => l.id == compra.lojaId)
        .firstOrNull;
    final artigos = {
      for (final a in ref.watch(artigosProvider).value ?? const <Artigo>[])
        a.id: a,
    };
    final linhas = ref.watch(linhasCompraProvider(compra.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          [loja?.nome ?? 'Loja apagada', ?compra.local].join(' · '),
          style: tema.textTheme.titleLarge,
        ),
        Text(formatarData(compra.data)),
        const SizedBox(height: 8),
        Text(
          formatarCent(compra.totalCent),
          style: tema.textTheme.headlineSmall,
        ),
        if (compra.poupancaCent > 0)
          Text('Poupança: ${formatarCent(compra.poupancaCent)}'),
        Text(origemCompra(compra.origem)),
        if (compra.rever)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: tema.colorScheme.error),
                const SizedBox(width: 8),
                const Expanded(child: Text(avisoRever)),
              ],
            ),
          ),
        const Divider(height: 32),
        linhas.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (erro, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('$erro', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(linhasCompraProvider(compra.id)),
                  child: const Text('Tentar outra vez'),
                ),
              ],
            ),
          ),
          data: (l) => _linhas(context, l, artigos),
        ),
      ],
    );
  }

  Widget _linhas(
    BuildContext context,
    List<LinhaCompra> linhas,
    Map<String, Artigo> artigos,
  ) {
    final tema = Theme.of(context);
    String nome(LinhaCompra l) =>
        artigos[l.artigoId]?.nome ?? l.textoOriginal ?? '—';
    final ordenadas = [...linhas]
      ..sort((a, b) => nome(a).toLowerCase().compareTo(nome(b).toLowerCase()));
    final soma = linhas.fold<int>(0, (s, l) => s + l.pagoCent);

    String detalhe(LinhaCompra l) {
      final peso = l.pesoG;
      final unit = l.precoUnitCent;
      return [
        if (peso != null)
          '${_kg.format(peso / 1000)} kg'
        else if (l.quantidade != null)
          '${l.quantidade} un',
        if (unit != null) '${formatarCent(unit)}${peso != null ? '/kg' : ''}',
      ].join(' · ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in ordenadas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(nome(l)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detalhe(l)),
                if (artigos[l.artigoId] != null &&
                    l.textoOriginal != null &&
                    l.textoOriginal != nome(l))
                  Text(l.textoOriginal!, style: tema.textTheme.bodySmall),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatarCent(l.pagoCent)),
                if (l.descontoCent > 0)
                  Text(
                    '-${formatarCent(l.descontoCent)}',
                    style: TextStyle(color: tema.colorScheme.primary),
                  ),
              ],
            ),
            onTap: artigos[l.artigoId] == null
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        DialogoVerArtigo(artigo: artigos[l.artigoId]!),
                  ),
          ),
        const Divider(),
        Text(
          'Soma das linhas: ${formatarCent(soma)}',
          textAlign: TextAlign.end,
          style: tema.textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// O detalhe num ecrã próprio (telemóvel, < 800 px).
class DetalheCompraPage extends ConsumerWidget {
  const DetalheCompraPage({super.key, required this.compra});

  final CompraResumo compra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loja = (ref.watch(lojasProvider).value ?? const <Loja>[])
        .where((l) => l.id == compra.lojaId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(loja?.nome ?? 'Compra')),
      body: DetalheCompra(compra: compra),
    );
  }
}
