import 'package:cabaz_mensal/core/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, escuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (escuro + 0.05);
}

void main() {
  for (final brilho in Brightness.values) {
    final tema = construirTema(brilho, fontesGoogle: false);
    final e = tema.colorScheme;
    final c = tema.extension<CoresCabaz>()!;

    group('contraste de texto ≥ 4,5:1 (${brilho.name})', () {
      final pares = {
        'onPrimary/primary': (e.onPrimary, e.primary),
        'onPrimaryContainer/primaryContainer': (
          e.onPrimaryContainer,
          e.primaryContainer,
        ),
        'onSecondary/secondary': (e.onSecondary, e.secondary),
        'onSecondaryContainer/secondaryContainer': (
          e.onSecondaryContainer,
          e.secondaryContainer,
        ),
        'onTertiary/tertiary': (e.onTertiary, e.tertiary),
        'onTertiaryContainer/tertiaryContainer': (
          e.onTertiaryContainer,
          e.tertiaryContainer,
        ),
        'onError/error': (e.onError, e.error),
        'onErrorContainer/errorContainer': (
          e.onErrorContainer,
          e.errorContainer,
        ),
        'onSurface/surface': (e.onSurface, e.surface),
        'onSurface/surfaceContainerLow': (e.onSurface, e.surfaceContainerLow),
        'onSurface/surfaceContainerHighest': (
          e.onSurface,
          e.surfaceContainerHighest,
        ),
        'onSurfaceVariant/surface': (e.onSurfaceVariant, e.surface),
        'onSurfaceVariant/surfaceContainerLow': (
          e.onSurfaceVariant,
          e.surfaceContainerLow,
        ),
        'onSurfaceVariant/surfaceContainerHighest': (
          e.onSurfaceVariant,
          e.surfaceContainerHighest,
        ),
        'onInverseSurface/inverseSurface': (
          e.onInverseSurface,
          e.inverseSurface,
        ),
        'sobreGradiente/gradienteInicio': (c.sobreGradiente, c.gradienteInicio),
        'sobreGradiente/gradienteFim': (c.sobreGradiente, c.gradienteFim),
        'primary/surface': (e.primary, e.surface),
        'primary/surfaceContainerLow': (e.primary, e.surfaceContainerLow),
        'tertiary/surface': (e.tertiary, e.surface),
        'tertiary/surfaceContainerLow': (e.tertiary, e.surfaceContainerLow),
        'error/surface': (e.error, e.surface),
        'error/surfaceContainerLow': (e.error, e.surfaceContainerLow),
        'textoFiltro/fundoFiltro': (c.textoFiltro, c.fundoFiltro),
        'ok/surface': (c.ok, e.surface),
        'ok/surfaceContainerLow': (c.ok, e.surfaceContainerLow),
      };
      for (final MapEntry(key: nome, value: (texto, fundo)) in pares.entries) {
        test(nome, () {
          expect(_contraste(texto, fundo), greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('pílulas contra o gradiente e ícone ≥ 3:1 (${brilho.name})', () {
      for (final azul in [c.gradienteInicio, c.gradienteFim]) {
        expect(_contraste(c.fundoFiltro, azul), greaterThanOrEqualTo(3));
      }
      expect(
        _contraste(c.gradienteInicio, c.fundoFiltro),
        greaterThanOrEqualTo(3),
      );
    });

    test('barras sobre a pista ≥ 3:1 (${brilho.name})', () {
      for (final cor in [c.ok, e.tertiary, e.error]) {
        expect(_contraste(cor, c.pista), greaterThanOrEqualTo(3));
      }
    });
  }

  test('paleta azul do plano (tema claro)', () {
    final tema = construirTema(Brightness.light, fontesGoogle: false);
    final e = tema.colorScheme;
    final c = tema.extension<CoresCabaz>()!;
    expect(e.primary, const Color(0xFF0B57D0));
    expect(e.primaryContainer, const Color(0xFFD3E3FD));
    expect(e.tertiary, const Color(0xFFB06000));
    expect(e.error, const Color(0xFFC5221F));
    expect(e.surface, const Color(0xFFFFFFFF));
    expect(c.gradienteInicio, const Color(0xFF0B57D0));
    expect(c.gradienteFim, const Color(0xFF1A6CE8));
    expect(c.ok, const Color(0xFF1E7E34));
  });

  testWidgets('CoresCabaz.of nos dois temas', (t) async {
    for (final brilho in Brightness.values) {
      late CoresCabaz lido;
      await t.pumpWidget(
        MaterialApp(
          theme: construirTema(brilho, fontesGoogle: false),
          home: Builder(
            builder: (context) {
              lido = CoresCabaz.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      // O MaterialApp anima a troca de tema: esperar pelo fim.
      await t.pumpAndSettle();
      expect(
        lido,
        brilho == Brightness.light ? CoresCabaz.claro : CoresCabaz.escuro,
      );
    }
  });

  test('lerp entre claro e escuro devolve as pontas', () {
    expect(CoresCabaz.claro.lerp(CoresCabaz.escuro, 0).ok, CoresCabaz.claro.ok);
    expect(
      CoresCabaz.claro.lerp(CoresCabaz.escuro, 1).ok,
      CoresCabaz.escuro.ok,
    );
  });
}
