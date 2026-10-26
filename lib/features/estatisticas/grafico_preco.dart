import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/formatos.dart';
import '../../domain/modelos.dart';
import 'cores.dart';

/// Evolução do preço de um artigo: uma linha por loja.
class GraficoPreco extends StatelessWidget {
  const GraficoPreco({super.key, required this.registos, required this.lojas});

  /// Registos de um artigo, por data crescente.
  final List<RegistoPreco> registos;
  final List<Loja> lojas;

  @override
  Widget build(BuildContext context) {
    if (registos.length < 2) {
      return const Text('Ainda não há registos suficientes para o gráfico.');
    }
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final porId = {for (final l in lojas) l.id: l};
    final porLoja = <String, List<RegistoPreco>>{};
    for (final r in registos) {
      (porLoja[r.lojaId] ??= []).add(r);
    }
    final ids = porLoja.keys.toList();
    String nome(String id) => porId[id]?.nome ?? 'Loja';
    Color cor(String id) {
      final l = porId[id];
      return l == null ? esquema.primary : corDaLoja(l, esquema);
    }

    final inicio = registos.first.data;
    double x(RegistoPreco r) => r.data.difference(inicio).inDays.toDouble();
    final precos = registos.map((r) => r.precoCent);
    final menor = precos.reduce(min);
    final maior = precos.reduce(max);
    final folga = max((maior - menor) * 0.2, 10) / 100;

    final descricao = [
      for (final id in ids)
        '${nome(id)}: ${formatarCent(porLoja[id]!.last.precoCent)} '
            'em ${formatarData(porLoja[id]!.last.data)}',
    ].join('; ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Evolução do preço. Último preço: $descricao',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: max(0, menor / 100 - folga),
                  maxY: maior / 100 + folga,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 64,
                        getTitlesWidget: (valor, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            formatarCent((valor * 100).round()),
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => esquema.inverseSurface,
                      getTooltipItems: (pontos) => [
                        for (final p in pontos)
                          LineTooltipItem(
                            '${nome(ids[p.barIndex])}\n'
                            '${formatarData(porLoja[ids[p.barIndex]]![p.spotIndex].data)}: '
                            '${formatarCent(porLoja[ids[p.barIndex]]![p.spotIndex].precoCent)}',
                            TextStyle(color: esquema.onInverseSurface),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    for (final id in ids)
                      LineChartBarData(
                        spots: [
                          for (final r in porLoja[id]!)
                            FlSpot(x(r), r.precoCent / 100),
                        ],
                        color: cor(id),
                        barWidth: 2,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final id in ids)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cor(id),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(nome(id)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
