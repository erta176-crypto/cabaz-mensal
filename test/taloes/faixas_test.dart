import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('faixasDa', () {
    test('imagem baixa: uma faixa, ampliada até 1440 px de largura', () {
      final f = faixasDa(1355, 1000);
      expect(f, hasLength(1));
      expect(f.single.y, 0);
      expect(f.single.altura, 1000);
      expect(f.single.escala, closeTo(1440 / 1355, 1e-9));
      expect((f.single.de, f.single.ate), (0.0, 1000.0));
    });

    test('imagem larga não é reduzida', () {
      expect(faixasDa(4000, 3000).single.escala, 1);
    });

    test('captura alta: faixas sobrepostas que cobrem tudo, sem buracos nem '
        'zonas repetidas', () {
      final f = faixasDa(720, 5282);
      expect(f.length, greaterThan(1));
      expect(f.first.de, 0);
      expect(f.last.ate, 5282);
      expect(f.last.y + f.last.altura, 5282);
      for (var i = 1; i < f.length; i++) {
        // A zona que conta de cada faixa começa onde acaba a da anterior.
        expect(f[i].de, f[i - 1].ate);
        // E há sobreposição real entre as imagens das duas faixas.
        expect(f[i].y, lessThan(f[i - 1].y + f[i - 1].altura));
      }
      for (final x in f) {
        expect(x.escala, 2);
        expect(x.altura, lessThanOrEqualTo(720 * 0.9));
      }
    });

    test('imagem muito estreita não fica em ciclo', () {
      expect(faixasDa(100, 2000).last.ate, 2000);
    });

    test('nenhuma faixa fica com menos de 32 px (limite do ML Kit)', () {
      for (final largura in [360, 720, 1080, 1355]) {
        for (var altura = 32; altura < 6000; altura += 37) {
          for (final x in faixasDa(largura, altura)) {
            expect(
              x.altura,
              greaterThanOrEqualTo(32),
              reason: '$largura×$altura',
            );
          }
        }
      }
    });
  });

  test('caixasDaFaixa: passa para coordenadas da imagem e larga as da '
      'sobreposição', () {
    const faixa = Faixa(y: 528, altura: 648, escala: 2, de: 588, ate: 1116);
    final r = caixasDaFaixa([
      // Centro na imagem: 528 + 220/2 = 638 → dentro.
      const CaixaOcr(
        texto: 'DENTRO',
        esquerda: 100,
        cima: 200,
        direita: 300,
        baixo: 240,
        angulo: 1,
      ),
      // Centro: 528 + 20/2 = 538 → na sobreposição de cima.
      const CaixaOcr(
        texto: 'CIMA',
        esquerda: 0,
        cima: 0,
        direita: 50,
        baixo: 40,
      ),
      // Centro: 528 + 1200/2 = 1128 → na sobreposição de baixo.
      const CaixaOcr(
        texto: 'BAIXO',
        esquerda: 0,
        cima: 1180,
        direita: 50,
        baixo: 1220,
      ),
    ], faixa);
    expect(r, hasLength(1));
    final c = r.single;
    expect(c.texto, 'DENTRO');
    expect(
      (c.esquerda, c.cima, c.direita, c.baixo),
      (50.0, 628.0, 150.0, 648.0),
    );
    expect(c.angulo, 1);
  });
}
