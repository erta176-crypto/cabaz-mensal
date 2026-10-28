/// Do resultado do OCR (caixas de texto com posição) ao texto do talão, uma
/// linha por artigo, como o dos PDFs. Regras em docs/planning/fase-7.md.
library;

import 'dart:math';

/// Uma linha de texto reconhecida, com a caixa em píxeis da imagem.
class CaixaOcr {
  const CaixaOcr({
    required this.texto,
    required this.esquerda,
    required this.cima,
    required this.direita,
    required this.baixo,
    this.angulo = 0,
  });

  final String texto;
  final double esquerda;
  final double cima;
  final double direita;
  final double baixo;

  /// Inclinação em graus (o ML Kit dá-a por linha).
  final double angulo;
}

double _mediana(List<double> valores) {
  final v = [...valores]..sort();
  return v[v.length ~/ 2];
}

/// Junta as caixas em linhas: o OCR separa a descrição e o preço. Pelo
/// centro vertical, corrigido pela inclinação mediana; caixas a menos de
/// meia altura de linha ficam na mesma linha, ordenadas da esquerda para a
/// direita.
String linhasDasCaixas(List<CaixaOcr> caixas) {
  if (caixas.isEmpty) return '';
  final tg = tan(_mediana([for (final c in caixas) c.angulo]) * pi / 180);
  final altura = _mediana([for (final c in caixas) c.baixo - c.cima]);
  final porAltura = [
    for (final c in caixas)
      (caixa: c, y: (c.cima + c.baixo) / 2 - (c.esquerda + c.direita) / 2 * tg),
  ]..sort((a, b) => a.y.compareTo(b.y));

  final linhas = <List<({CaixaOcr caixa, double y})>>[];
  for (final c in porAltura) {
    final atual = linhas.lastOrNull;
    if (atual != null) {
      final y = atual.map((p) => p.y).reduce((a, b) => a + b) / atual.length;
      if ((c.y - y).abs() < altura / 2) {
        atual.add(c);
        continue;
      }
    }
    linhas.add([c]);
  }
  return [
    for (final l in linhas)
      (l..sort((a, b) => a.caixa.esquerda.compareTo(b.caixa.esquerda)))
          .map((p) => p.caixa.texto)
          .join(' '),
  ].join('\n');
}

final _virgula = RegExp(r'(\d), (\d)');
final _vezes = RegExp(r'(\d) [xX] ?(\d+,\d)');
final _kg = RegExp(r'EUR/K[gG]');
final _pontoNoValor = RegExp(r'(\d+)\.(\d{2}) ([A-Z])$');
final _espacos = RegExp(r'\s+');

/// Erros típicos do OCR em números e unidades: "1, 09", "2 X0,89",
/// "EUR/Kg", "3.70 D". Só mexe em números com vírgula decimal (o E.Leclerc
/// usa ponto e "X" maiúsculo, e fica igual).
String normalizarOcr(String texto) => texto
    .split('\n')
    .map(
      (l) => l
          .replaceAllMapped(_virgula, (m) => '${m[1]},${m[2]}')
          .replaceAllMapped(_vezes, (m) => '${m[1]} x ${m[2]}')
          .replaceAll(_kg, 'EUR/kg')
          .replaceAllMapped(_pontoNoValor, (m) => '${m[1]},${m[2]} ${m[3]}')
          .replaceAll(_espacos, ' ')
          .trim(),
    )
    .join('\n');
