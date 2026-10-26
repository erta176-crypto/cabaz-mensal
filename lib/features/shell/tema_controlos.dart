import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/preferencias.dart';

/// Botão sol/lua do menu lateral: troca entre claro e escuro (deixa de
/// seguir o sistema).
class BotaoTema extends ConsumerWidget {
  const BotaoTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(escuro ? Icons.light_mode : Icons.dark_mode),
      tooltip: escuro ? 'Mudar para modo claro' : 'Mudar para modo escuro',
      onPressed: () => ref
          .read(temaProvider.notifier)
          .escolher(escuro ? ModoTema.claro : ModoTema.escuro),
    );
  }
}

/// Menu "Tema" das Definições: Sistema, Claro ou Escuro.
class MenuTema extends ConsumerWidget {
  const MenuTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(temaProvider);
    return DropdownButtonFormField<ModoTema>(
      // A chave reconstrói o menu quando a escolha guardada chega.
      key: ValueKey(atual),
      initialValue: atual,
      decoration: const InputDecoration(labelText: 'Tema'),
      items: [
        for (final m in ModoTema.values)
          DropdownMenuItem(value: m, child: Text(m.rotulo)),
      ],
      onChanged: (m) {
        if (m != null) ref.read(temaProvider.notifier).escolher(m);
      },
    );
  }
}
