import 'package:flutter/material.dart';

import '../../core/formatos.dart';

/// Barras horizontais simples (sem `fl_chart`): rótulo, barra e valor.
/// Com [aoTocar], a linha é um botão (Fase 14).
class BarrasHorizontais extends StatelessWidget {
  const BarrasHorizontais({super.key, required this.itens});

  final List<({String rotulo, int cent, Color cor, VoidCallback? aoTocar})>
  itens;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const Text('Sem dados no período.');
    final tema = Theme.of(context);
    final maximo = itens.map((i) => i.cent).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final i in itens)
          Semantics(
            label: '${i.rotulo}: ${formatarCent(i.cent)}',
            button: i.aoTocar != null,
            onTap: i.aoTocar,
            excludeSemantics: true,
            child: InkWell(
              onTap: i.aoTocar,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                // Área de toque de 48 px quando a linha é um botão.
                constraints: BoxConstraints(
                  minHeight: i.aoTocar == null ? 0 : 48,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          i.rotulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: maximo <= 0 ? 0 : i.cent / maximo,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: i.cor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatarCent(i.cent),
                        style: tema.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
