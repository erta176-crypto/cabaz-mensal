import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores quentes e sóbrias (ver prompt da Fase 0).
abstract final class Cores {
  static const fundo = Color(0xFFFAF6F0);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF2A211C);
  static const textoSecundario = Color(0xFF6B5D53);
  static const linhas = Color(0xFFE8DDD2);
  static const terracota = Color(0xFFB4532A);
  static const tomSuave = Color(0xFFF6E3D6);
  static const textoTomSuave = Color(0xFF8A3A18);

  // Equivalentes escuros, com os mesmos tons aquecidos.
  static const fundoEscuro = Color(0xFF1C1714);
  static const superficieEscura = Color(0xFF262019);
  static const textoEscuro = Color(0xFFF3EBE3);
  static const textoSecundarioEscuro = Color(0xFFBCAD9F);
  static const linhasEscuras = Color(0xFF3D332B);
  static const terracotaEscura = Color(0xFFE08A60);
  static const tomSuaveEscuro = Color(0xFF4A2A1B);
  static const textoTomSuaveEscuro = Color(0xFFF6D3BE);
}

ColorScheme _esquema(Brightness b) {
  final claro = b == Brightness.light;
  return ColorScheme(
    brightness: b,
    primary: claro ? Cores.terracota : Cores.terracotaEscura,
    onPrimary: claro ? Colors.white : const Color(0xFF2A1408),
    primaryContainer: claro ? Cores.tomSuave : Cores.tomSuaveEscuro,
    onPrimaryContainer: claro ? Cores.textoTomSuave : Cores.textoTomSuaveEscuro,
    secondary: claro ? Cores.textoSecundario : Cores.textoSecundarioEscuro,
    onSecondary: claro ? Colors.white : Cores.fundoEscuro,
    secondaryContainer: claro ? Cores.tomSuave : Cores.tomSuaveEscuro,
    onSecondaryContainer: claro
        ? Cores.textoTomSuave
        : Cores.textoTomSuaveEscuro,
    error: claro ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
    onError: claro ? Colors.white : const Color(0xFF601410),
    surface: claro ? Cores.fundo : Cores.fundoEscuro,
    onSurface: claro ? Cores.texto : Cores.textoEscuro,
    onSurfaceVariant: claro
        ? Cores.textoSecundario
        : Cores.textoSecundarioEscuro,
    surfaceContainerLowest: claro ? Cores.superficie : Cores.fundoEscuro,
    surfaceContainerLow: claro ? Cores.superficie : Cores.superficieEscura,
    surfaceContainer: claro ? const Color(0xFFF5EFE7) : Cores.superficieEscura,
    surfaceContainerHigh: claro
        ? const Color(0xFFF1E9DF)
        : const Color(0xFF2E2620),
    surfaceContainerHighest: claro
        ? const Color(0xFFECE2D7)
        : const Color(0xFF362D26),
    outline: claro ? const Color(0xFFB9A99A) : const Color(0xFF6E6054),
    outlineVariant: claro ? Cores.linhas : Cores.linhasEscuras,
  );
}

/// [fontesGoogle] é false nos testes (sem rede).
ThemeData construirTema(Brightness brilho, {bool fontesGoogle = true}) {
  final esquema = _esquema(brilho);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: esquema.surface,
  );

  var texto = base.textTheme;
  if (fontesGoogle) {
    texto = texto.apply(fontFamily: GoogleFonts.instrumentSans().fontFamily);
    final titulos = GoogleFonts.bricolageGrotesque().fontFamily;
    TextStyle? t(TextStyle? s) =>
        s?.copyWith(fontFamily: titulos, fontWeight: FontWeight.w600);
    texto = texto.copyWith(
      displayLarge: t(texto.displayLarge),
      displayMedium: t(texto.displayMedium),
      displaySmall: t(texto.displaySmall),
      headlineLarge: t(texto.headlineLarge),
      headlineMedium: t(texto.headlineMedium),
      headlineSmall: t(texto.headlineSmall),
      titleLarge: t(texto.titleLarge),
    );
  }
  texto = texto.apply(
    bodyColor: esquema.onSurface,
    displayColor: esquema.onSurface,
  );

  final superficieCartao = esquema.surfaceContainerLow;

  return base.copyWith(
    textTheme: texto,
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: texto.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: superficieCartao,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: superficieCartao,
      indicatorColor: esquema.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: superficieCartao,
      indicatorColor: esquema.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: superficieCartao,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
      // Rótulo sempre por cima do campo.
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(backgroundColor: superficieCartao),
  );
}
