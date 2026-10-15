import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../shell/shell.dart';

const palavraConfirmacao = 'APAGAR';

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
    final cores = Theme.of(context).colorScheme;
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
                    leading: const Icon(Icons.logout),
                    title: const Text('Sair'),
                    onTap: () => ref.read(authRepositoryProvider).sair(),
                  ),
                ],
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
            'Isto apaga tudo desta conta. Para confirmar, escreve '
            '$palavraConfirmacao.',
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
