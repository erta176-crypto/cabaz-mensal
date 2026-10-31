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
// Duas casas decimais: "AGUA 6X1,5L" é texto do artigo e fica igual.
final _vezes = RegExp(r'(\d) ?[xX] ?(\d+,\d{2})\b');
final _kg = RegExp(r'EUR/K[gG]');
final _pontoNoValor = RegExp(r'(\d+)\.(\d{2}) ([A-Z])$');
final _pontoFinal = RegExp(r'(\d,\d{2})\.$');
final _espacos = RegExp(r'\s+');

/// Erros típicos do OCR em números e unidades: "1, 09", "2 X0,89", "2x 1,19",
/// "EUR/Kg", "3.70 D", "1,19." no fim. Só mexe em números com vírgula
/// decimal (o E.Leclerc usa ponto e "X" maiúsculo, e fica igual).
String normalizarOcr(String texto) => texto
    .split('\n')
    .map(
      (l) => l
          .replaceAllMapped(_virgula, (m) => '${m[1]},${m[2]}')
          .replaceAllMapped(_vezes, (m) => '${m[1]} x ${m[2]}')
          .replaceAll(_kg, 'EUR/kg')
          .replaceAllMapped(_pontoNoValor, (m) => '${m[1]},${m[2]} ${m[3]}')
          .replaceAll(_espacos, ' ')
          .trim()
          .replaceAllMapped(_pontoFinal, (m) => m[1]!),
    )
    .join('\n');

/// Uma faixa horizontal da imagem para o OCR: [y] e [altura] em píxeis da
/// imagem; [escala] é a ampliação dada ao ML Kit. Só contam as caixas com o
/// centro entre [de] e [ate] (o resto é sobreposição com a faixa vizinha).
class Faixa {
  const Faixa({
    required this.y,
    required this.altura,
    required this.escala,
    required this.de,
    required this.ate,
  });

  final double y;
  final double altura;
  final double escala;
  final double de;
  final double ate;
}

/// Largura que se dá ao ML Kit: a letra pequena das capturas só se lê assim.
const _larguraOcr = 1440.0;

/// Sobreposição entre faixas, para nenhuma linha ficar cortada a meio.
const _sobra = 120.0;

/// Faixas de altura ≈ 0,9 × largura, sobrepostas, que cobrem a imagem toda.
/// Como cada faixa só acaba depois da sobreposição, a última tem sempre mais
/// de 120 px (o ML Kit recusa menos de 32).
List<Faixa> faixasDa(int largura, int altura) {
  final escala = max(1.0, _larguraOcr / largura);
  final alto = max((largura * 0.9).floorToDouble(), 2 * _sobra);
  final faixas = <Faixa>[];
  var y = 0.0;
  while (true) {
    final h = min(alto, altura - y);
    final ultima = y + h >= altura;
    faixas.add(
      Faixa(
        y: y,
        altura: h,
        escala: escala,
        de: y == 0 ? 0 : y + _sobra / 2,
        ate: ultima ? altura.toDouble() : y + h - _sobra / 2,
      ),
    );
    if (ultima) return faixas;
    y += alto - _sobra;
  }
}

/// Caixas lidas numa faixa (ampliada) → coordenadas da imagem, só as que
/// pertencem à faixa.
List<CaixaOcr> caixasDaFaixa(List<CaixaOcr> caixas, Faixa f) => [
  for (final c in caixas)
    if (f.y + (c.cima + c.baixo) / 2 / f.escala case final centro
        when centro >= f.de && centro < f.ate)
      CaixaOcr(
        texto: c.texto,
        esquerda: c.esquerda / f.escala,
        cima: f.y + c.cima / f.escala,
        direita: c.direita / f.escala,
        baixo: f.y + c.baixo / f.escala,
        angulo: c.angulo,
      ),
];
