import 'package:flutter/material.dart';

import '../shell/shell.dart';

class EmBrevePage extends StatelessWidget {
  const EmBrevePage({super.key, required this.titulo, required this.fase});

  final String titulo;
  final int fase;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Pagina(
      titulo: titulo,
      corpo: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, size: 48, color: cores.primary),
              const SizedBox(height: 16),
              Text(
                'Em breve (Fase $fase)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Este ecrã chega numa próxima fase.',
                style: TextStyle(color: cores.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
