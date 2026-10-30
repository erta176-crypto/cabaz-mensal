import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desbloqueio.dart';
import '../../data/providers.dart';
import '../../data/repositorios.dart';
import '../../domain/preferencias.dart';
import '../shell/faixa_sync.dart';
import '../shell/shell.dart';
import '../shell/tema_controlos.dart';

const palavraConfirmacao = 'APAGAR';

/// Sair da conta (Definições e ecrã de bloqueio): avisa se há alterações por
/// enviar e limpa os dados deste aparelho.
Future<void> sairDaConta(BuildContext context, WidgetRef ref) async {
  // Depois de sair, o router troca de página: o ref pode já não servir.
  final sync = ref.read(syncRepositoryProvider);
  final contentor = ProviderScope.containerOf(context, listen: false);
  final estado = ref.read(estadoSyncProvider).value ?? const EstadoSync();
  final porEnviar = estado.pendentes + estado.comErro;
  if (porEnviar > 0) {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair com alterações por enviar?'),
        content: Text(
          'Há $porEnviar ${porEnviar == 1 ? 'alteração' : 'alterações'} '
          'que ainda não chegaram ao servidor. Se saíres agora, perdem-se.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair e perder'),
          ),
        ],
      ),
    );
    if (sair != true) return;
  }
  // Os dados ficam no servidor; o dispositivo não guarda nada de outra conta.
  await ref.read(authRepositoryProvider).sair();
  await sync.limparLocal();
  // limparTudo apagou a chave `bloqueio`.
  contentor.invalidate(bloqueioProvider);
}

class DefinicoesPage extends ConsumerWidget {
  const DefinicoesPage({super.key});

  Future<void> _apagarTudo(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmarApagar(),
    );
    if (confirmado != true || !context.mounted) return;
    final mensagens = ScaffoldMessenger.of(context);
    try {
      await ref.read(dadosRepositoryProvider).apagarTudo();
      await ref
          .read(syncRepositoryProvider)
          .recarregarTudo(descartarPendentes: true);
      mensagens.showSnackBar(
        const SnackBar(content: Text('Todos os dados foram apagados.')),
      );
    } catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(sessaoProvider).value;
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    final estado = ref.watch(estadoSyncProvider).value ?? const EstadoSync();
    final cores = Theme.of(context).colorScheme;
    final tema = Theme.of(context);

    void guardar(Preferencias p) =>
        ref.read(preferenciasRepositoryProvider).guardar(p);

    Widget menuGesto(
      String rotulo,
      AcaoGesto valor,
      Preferencias Function(AcaoGesto) mudar,
    ) => DropdownMenu<AcaoGesto>(
      key: ValueKey('$rotulo-$valor'),
      label: Text(rotulo),
      expandedInsets: EdgeInsets.zero,
      initialSelection: valor,
      onSelected: (v) => v == null ? null : guardar(mudar(v)),
      dropdownMenuEntries: [
        for (final a in AcaoGesto.values)
          DropdownMenuEntry(value: a, label: a.rotulo),
      ],
    );

    return Pagina(
      titulo: 'Definições',
      corpo: ConteudoCentrado(
        largura: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Conta'),
                    subtitle: Text(
                      email ?? ref.read(authRepositoryProvider).email ?? '—',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Sincronização'),
                    subtitle: Text(switch (estado) {
                      EstadoSync(comErro: > 0) =>
                        '${estado.comErro} com erro · toca para ver',
                      EstadoSync(online: false) =>
                        'Sem rede · ${estado.pendentes} por enviar',
                      EstadoSync(pendentes: > 0) =>
                        '${estado.pendentes} por enviar',
                      _ => 'Tudo enviado',
                    }),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => const DialogoPendentes(),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sair'),
                    onTap: () => sairDaConta(context, ref),
                  ),
                ],
              ),
            ),
            if (ref.watch(desbloqueioDisponivelProvider).value ?? false) ...[
              const SizedBox(height: 16),
              const _CartaoBloqueio(),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Aparência', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    const MenuTema(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Gestos na Lista', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    menuGesto(
                      'Deslizar para a direita',
                      prefs.direita,
                      (v) => prefs.copyWith(direita: v),
                    ),
                    const SizedBox(height: 16),
                    menuGesto(
                      'Deslizar para a esquerda',
                      prefs.esquerda,
                      (v) => prefs.copyWith(esquerda: v),
                    ),
                    const SizedBox(height: 16),
                    menuGesto(
                      'Tocar no artigo',
                      prefs.tocar,
                      (v) => prefs.copyWith(tocar: v),
                    ),
                    if (prefs.gestosRepetidos) ...[
                      const SizedBox(height: 12),
                      Text(
                        'As duas direções fazem o mesmo: '
                        '"${prefs.direita.rotulo}".',
                        style: TextStyle(color: cores.error),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => guardar(
                          prefs.copyWith(
                            direita: const Preferencias().direita,
                            esquerda: const Preferencias().esquerda,
                            tocar: const Preferencias().tocar,
                          ),
                        ),
                        child: const Text('Repor os gestos de origem'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: cores.error),
                title: Text(
                  'Apagar todos os dados',
                  style: TextStyle(color: cores.error),
                ),
                subtitle: const Text(
                  'Lojas, artigos, compras, preços e listas. '
                  'Não pode ser anulado.',
                ),
                onTap: () => _apagarTudo(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloqueio com biometria ou PIN do telemóvel (Fase 8, D4): só aparece onde
/// o aparelho o permite.
class _CartaoBloqueio extends ConsumerWidget {
  const _CartaoBloqueio();

  Future<void> _mudar(BuildContext context, WidgetRef ref, bool ligar) async {
    final bloqueio = ref.read(bloqueioProvider.notifier);
    if (!ligar) return bloqueio.desligar();
    final mensagens = ScaffoldMessenger.of(context);
    try {
      await bloqueio.ligar();
    } on ErroDesbloqueio catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Bloquear com impressão digital ou PIN'),
      subtitle: const Text(
        'Ao abrir a app e ao voltar a ela depois de 5 minutos.',
      ),
      value: ref.watch(bloqueioProvider).value ?? false,
      onChanged: (v) => _mudar(context, ref, v),
    ),
  );
}

class _ConfirmarApagar extends StatefulWidget {
  const _ConfirmarApagar();

  @override
  State<_ConfirmarApagar> createState() => _ConfirmarApagarState();
}

class _ConfirmarApagarState extends State<_ConfirmarApagar> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _texto.text.trim() == palavraConfirmacao;
    return AlertDialog(
      title: const Text('Apagar todos os dados?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Isto apaga tudo desta conta, em todos os dispositivos. Para '
            'confirmar, escreve $palavraConfirmacao.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _texto,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Confirmação'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Apagar tudo'),
        ),
      ],
    );
  }
}
