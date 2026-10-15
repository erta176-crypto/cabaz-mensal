import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositorios.dart';

/// Indicador discreto no topo: "Sem rede · N alterações por enviar",
/// "A sincronizar…" ou "N alterações com erro". Não aparece nada quando está
/// tudo enviado. Também arranca o sincronizador e sincroniza quando a app
/// volta ao primeiro plano.
class FaixaSync extends ConsumerStatefulWidget {
  const FaixaSync({super.key});

  @override
  ConsumerState<FaixaSync> createState() => _FaixaSyncState();
}

class _FaixaSyncState extends ConsumerState<FaixaSync> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onResume: () => ref.read(syncRepositoryProvider).sincronizar(),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Manter o sincronizador vivo enquanto houver sessão.
    ref.watch(sincronizadorProvider);
    final estado = ref.watch(estadoSyncProvider).value ?? const EstadoSync();
    final cores = Theme.of(context).colorScheme;

    final (String texto, IconData icone, Color fundo, Color frente)? f =
        switch (estado) {
          EstadoSync(comErro: > 0) => (
            '${estado.comErro} '
                '${estado.comErro == 1 ? 'alteração' : 'alterações'} com erro',
            Icons.error_outline,
            cores.errorContainer,
            cores.onErrorContainer,
          ),
          EstadoSync(online: false) => (
            estado.pendentes == 0
                ? 'Sem rede'
                : 'Sem rede · ${estado.pendentes} '
                      '${estado.pendentes == 1 ? 'alteração' : 'alterações'} '
                      'por enviar',
            Icons.cloud_off,
            cores.secondaryContainer,
            cores.onSecondaryContainer,
          ),
          EstadoSync(pendentes: > 0) => (
            'A sincronizar…',
            Icons.cloud_sync_outlined,
            cores.surfaceContainerHigh,
            cores.onSurfaceVariant,
          ),
          _ => null,
        };
    if (f == null) return const SizedBox.shrink();
    final (texto, icone, fundo, frente) = f;

    return Material(
      color: fundo,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => const DialogoPendentes(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icone, size: 18, color: frente),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(color: frente, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: frente),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista das alterações por enviar e das recusadas pelo servidor.
class DialogoPendentes extends ConsumerWidget {
  const DialogoPendentes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(pendentesProvider).value ?? const [];
    final estado = ref.watch(estadoSyncProvider).value ?? const EstadoSync();
    final cores = Theme.of(context).colorScheme;
    final ultima = estado.ultimaSincronizacao;
    final diagnostico = [
      estado.online ? 'Ligado ao servidor' : 'Sem ligação ao servidor',
      ultima == null
          ? 'Ainda não sincronizou nesta sessão'
          : 'Última sincronização: '
                '${ultima.hour.toString().padLeft(2, '0')}:'
                '${ultima.minute.toString().padLeft(2, '0')}:'
                '${ultima.second.toString().padLeft(2, '0')}',
      if (estado.ultimoErro != null) 'Último erro: ${estado.ultimoErro}',
    ].join('\n');
    return AlertDialog(
      title: const Text('Alterações por enviar'),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            SelectableText(
              diagnostico,
              style: TextStyle(fontSize: 12, color: cores.onSurfaceVariant),
            ),
            const Divider(),
            if (lista.isEmpty) const Text('Está tudo enviado.'),
            for (final p in lista)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  p.erro == null ? Icons.schedule : Icons.error_outline,
                  color: p.erro == null ? null : cores.error,
                ),
                title: Text(p.descricao),
                subtitle: p.erro == null
                    ? (p.tentativas > 0
                          ? Text('${p.tentativas} tentativas')
                          : null)
                    : Text(p.erro!),
                trailing: p.erro == null
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Ações',
                        onSelected: (_) =>
                            ref.read(syncRepositoryProvider).descartar(p.id),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'descartar',
                            child: Text('Descartar e recarregar'),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => ref.read(syncRepositoryProvider).sincronizar(),
          child: const Text('Tentar agora'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
