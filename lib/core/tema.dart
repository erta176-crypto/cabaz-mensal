import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta violeta, azul e castanho claro sobre creme (decisão 0008).
abstract final class Cores {
  static const fundo = Color(0xFFF8F6F2);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF26222E);
  static const textoSecundario = Color(0xFF625B6E);
  static const linhas = Color(0xFFE4DFE8);
  static const violeta = Color(0xFF5B4B9A);
  static const lavanda = Color(0xFFE9E4F7);
  static const textoLavanda = Color(0xFF2E2463);
  static const azul = Color(0xFF3A6EA5);
  static const azulSuave = Color(0xFFDCE8F5);
  static const textoAzulSuave = Color(0xFF173A5E);
  static const castanho = Color(0xFF8A6A4F);
  static const areia = Color(0xFFF1E6DA);
  static const textoAreia = Color(0xFF4A3424);

  // Equivalentes escuros.
  static const fundoEscuro = Color(0xFF17151C);
  static const superficieEscura = Color(0xFF211E28);
  static const textoEscuro = Color(0xFFEDE9F3);
  static const textoSecundarioEscuro = Color(0xFFB7AFC4);
  static const linhasEscuras = Color(0xFF38333F);
  static const violetaEscura = Color(0xFFB8A9F0);
  static const lavandaEscura = Color(0xFF3D3270);
  static const textoLavandaEscura = Color(0xFFE6E0FA);
  static const azulEscuro = Color(0xFF9EC3EA);
  static const azulSuaveEscuro = Color(0xFF1F3F60);
  static const textoAzulSuaveEscuro = Color(0xFFD6E6F6);
  static const castanhoEscuro = Color(0xFFD9BFA4);
  static const areiaEscura = Color(0xFF4A3A2C);
  static const textoAreiaEscura = Color(0xFFF3E4D4);
}

ColorScheme _esquema(Brightness b) {
  final claro = b == Brightness.light;
  return ColorScheme(
    brightness: b,
    primary: claro ? Cores.violeta : Cores.violetaEscura,
    onPrimary: claro ? Colors.white : const Color(0xFF271C55),
    primaryContainer: claro ? Cores.lavanda : Cores.lavandaEscura,
    onPrimaryContainer: claro ? Cores.textoLavanda : Cores.textoLavandaEscura,
    secondary: claro ? Cores.azul : Cores.azulEscuro,
    onSecondary: claro ? Colors.white : const Color(0xFF0E2F4F),
    secondaryContainer: claro ? Cores.azulSuave : Cores.azulSuaveEscuro,
    onSecondaryContainer: claro
        ? Cores.textoAzulSuave
        : Cores.textoAzulSuaveEscuro,
    tertiary: claro ? Cores.castanho : Cores.castanhoEscuro,
    onTertiary: claro ? Colors.white : const Color(0xFF3B2A1C),
    tertiaryContainer: claro ? Cores.areia : Cores.areiaEscura,
    onTertiaryContainer: claro ? Cores.textoAreia : Cores.textoAreiaEscura,
    error: claro ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
    onError: claro ? Colors.white : const Color(0xFF601410),
    surface: claro ? Cores.fundo : Cores.fundoEscuro,
    onSurface: claro ? Cores.texto : Cores.textoEscuro,
    onSurfaceVariant: claro
        ? Cores.textoSecundario
        : Cores.textoSecundarioEscuro,
    surfaceContainerLowest: claro ? Cores.superficie : Cores.fundoEscuro,
    surfaceContainerLow: claro ? Cores.superficie : Cores.superficieEscura,
    surfaceContainer: claro ? const Color(0xFFF3F0EC) : const Color(0xFF26222D),
    surfaceContainerHigh: claro
        ? const Color(0xFFEEEAE5)
        : const Color(0xFF2D2935),
    surfaceContainerHighest: claro
        ? const Color(0xFFE8E3DD)
        : const Color(0xFF35303E),
    outline: claro ? const Color(0xFFADA4B8) : const Color(0xFF6F6779),
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
