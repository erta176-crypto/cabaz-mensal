import 'package:flutter/material.dart';

import '../../import/campos.dart';
import '../../import/previsualizacao.dart';
import '../../import/tabela_lida.dart';

/// Linhas mostradas na tabela (o resumo e o botão contam todas).
const _maxLinhasVisiveis = 200;

/// Pré-visualização antes de gravar: um menu por coluna, as opções do tipo,
/// a tabela com o estado de cada linha, o resumo e "Importar N linhas".
class PrevisualizacaoCard extends StatelessWidget {
  const PrevisualizacaoCard({
    super.key,
    required this.nomeFicheiro,
    required this.tabela,
    required this.tipo,
    required this.campos,
    required this.previa,
    required this.aoMudarCampo,
    required this.opcoes,
    required this.online,
    required this.aGravar,
    required this.aoImportar,
    required this.aoCancelar,
  });

  final String nomeFicheiro;
  final TabelaLida tabela;
  final TipoImportacao tipo;
  final List<Campo> campos;
  final Previsualizacao previa;
  final void Function(int coluna, Campo campo) aoMudarCampo;

  /// Menus próprios do tipo (ex.: "Se o artigo já existir").
  final List<Widget> opcoes;
  final bool online;
  final bool aGravar;
  final VoidCallback aoImportar;
  final VoidCallback aoCancelar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    Color corDe(EstadoLinha e) => switch (e) {
      EstadoLinha.novo => Colors.green.shade700,
      EstadoLinha.atualiza => cores.primary,
      EstadoLinha.jaExiste => cores.onSurfaceVariant,
      EstadoLinha.erro => cores.error,
      EstadoLinha.ignorada => cores.outline,
    };
    final n = previa.aImportar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pré-visualização · $nomeFicheiro',
                    style: tema.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  onPressed: aGravar ? null : aoCancelar,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Colunas do ficheiro', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, h) in tabela.cabecalhos.indexed)
                  DropdownMenu<Campo>(
                    key: ValueKey('coluna-$i-${campos[i]}'),
                    label: Text(h.isEmpty ? 'Coluna ${i + 1}' : h),
                    width: 200,
                    initialSelection: campos[i],
                    onSelected: (c) => c == null ? null : aoMudarCampo(i, c),
                    dropdownMenuEntries: [
                      for (final c in [Campo.ignorar, ...tipo.campos])
                        DropdownMenuEntry(value: c, label: c.rotulo),
                    ],
                  ),
                ...opcoes,
              ],
            ),
            const SizedBox(height: 16),
            Text(previa.resumo, style: tema.textTheme.titleMedium),
            if (previa.comAviso > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${previa.comAviso} linhas com aviso: ver a coluna Estado.',
                  style: TextStyle(color: cores.error),
                ),
              ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 48,
                columns: [
                  const DataColumn(label: Text('#')),
                  const DataColumn(label: Text('Estado')),
                  for (final h in tabela.cabecalhos) DataColumn(label: Text(h)),
                ],
                rows: [
                  for (final l in previa.linhas.take(_maxLinhasVisiveis))
                    DataRow(
                      cells: [
                        DataCell(Text('${l.numero}')),
                        DataCell(
                          Text(
                            [l.estado.rotulo, ?l.motivo, ?l.aviso].join(' · '),
                            style: TextStyle(color: corDe(l.estado)),
                          ),
                        ),
                        for (final v in l.valores) DataCell(Text(v)),
                      ],
                    ),
                ],
              ),
            ),
            if (previa.linhas.length > _maxLinhasVisiveis)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'A mostrar $_maxLinhasVisiveis de ${previa.linhas.length} '
                  'linhas.',
                  style: TextStyle(color: cores.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 16),
            if (!online)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sem rede: a importação grava no servidor numa só '
                  'transação. Liga a rede para importar.',
                  style: TextStyle(color: cores.error),
                ),
              ),
            FilledButton(
              onPressed: online && n > 0 && !aGravar ? aoImportar : null,
              child: Text(
                aGravar
                    ? 'A importar…'
                    : 'Importar $n ${n == 1 ? 'linha' : 'linhas'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
