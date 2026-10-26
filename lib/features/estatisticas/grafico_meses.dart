import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../domain/estatisticas.dart';

final _mesCurto = DateFormat('MMM', 'pt_PT');
final _mesLongo = DateFormat('MMMM y', 'pt_PT');
final _ano = DateFormat("''yy", 'pt_PT');

/// Gasto por mês: uma barra por mês; os valores ficam no tooltip.
class GraficoMeses extends StatelessWidget {
  const GraficoMeses({super.key, required this.meses});

  final List<TotalMes> meses;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final maior = meses.fold<int>(
      0,
      (m, t) => t.totalCent > m ? t.totalCent : m,
    );
    final descricao = meses
        .map((m) => '${_mesLongo.format(m.mes)}: ${formatarCent(m.totalCent)}')
        .join('; ');

    Widget rotulo(double valor, TitleMeta meta) {
      final i = valor.toInt();
      final m = meses[i].mes;
      final comAno = i == 0 || m.month == 1;
      return SideTitleWidget(
        meta: meta,
        child: Text(
          comAno
              ? '${_mesCurto.format(m)}\n${_ano.format(m)}'
              : _mesCurto.format(m),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Semantics(
      label: 'Gasto por mês. $descricao',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maior <= 0 ? 1 : maior / 100 * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: rotulo,
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => esquema.inverseSurface,
                  getTooltipItem: (grupo, _, _, _) {
                    final m = meses[grupo.x];
                    return BarTooltipItem(
                      '${_mesLongo.format(m.mes)}\n${formatarCent(m.totalCent)}',
                      TextStyle(color: esquema.onInverseSurface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < meses.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: meses[i].totalCent / 100,
                        color: esquema.secondary,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
