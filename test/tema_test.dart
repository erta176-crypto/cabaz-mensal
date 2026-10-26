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
    group('contraste ≥ 4,5:1 (${brilho.name})', () {
      final e = construirTema(brilho, fontesGoogle: false).colorScheme;
      final pares = {
        'onSurface/surface': (e.onSurface, e.surface),
        'onSurface/surfaceContainerLow': (e.onSurface, e.surfaceContainerLow),
        'onSurfaceVariant/surface': (e.onSurfaceVariant, e.surface),
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
        'onTertiaryContainer/tertiaryContainer': (
          e.onTertiaryContainer,
          e.tertiaryContainer,
        ),
        'onError/error': (e.onError, e.error),
      };
      for (final MapEntry(key: nome, value: (texto, fundo)) in pares.entries) {
        test(nome, () {
          expect(_contraste(texto, fundo), greaterThanOrEqualTo(4.5));
        });
      }
    });
  }

  test('paleta violeta: primary, secondary e tertiary do plano', () {
    final e = construirTema(Brightness.light, fontesGoogle: false).colorScheme;
    expect(e.primary, const Color(0xFF5B4B9A));
    expect(e.secondary, const Color(0xFF3A6EA5));
    expect(e.tertiary, const Color(0xFF8A6A4F));
    expect(e.tertiaryContainer, const Color(0xFFF1E6DA));
  });
}
