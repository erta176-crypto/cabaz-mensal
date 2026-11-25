import 'package:flutter/material.dart';

import '../../core/formatos.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';

/// Confirmação antes de eliminar um talão (Fase 15, D5). Devolve true para
/// eliminar.
class DialogoEliminarTalao extends StatelessWidget {
  const DialogoEliminarTalao({
    super.key,
    required this.compra,
    required this.loja,
  });

  final CompraResumo compra;
  final Loja? loja;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Eliminar talão?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [loja?.nome ?? 'Loja apagada', ?compra.local].join(' · '),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(formatarData(compra.data)),
        Text(formatarCent(compra.totalCent)),
        const SizedBox(height: 12),
        const Text('Sai do Histórico e do Painel. Podes anular logo a seguir.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Eliminar'),
      ),
    ],
  );
}

/// "⋮" de um talão com "Eliminar talão".
class MenuTalao extends StatelessWidget {
  const MenuTalao({super.key, required this.aoEliminar});

  final VoidCallback aoEliminar;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    tooltip: 'Ações do talão',
    onSelected: (_) => aoEliminar(),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'eliminar', child: Text('Eliminar talão')),
    ],
  );
}
