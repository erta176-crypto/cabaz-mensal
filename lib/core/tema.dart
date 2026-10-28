import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta azul: cabeçalho em gradiente, fundo e cartões brancos, verde/âmbar/
/// vermelho para os níveis (decisão 0011, que substitui a 0008).
abstract final class Cores {
  // Claro.
  static const azul = Color(0xFF0B57D0);
  static const azul2 = Color(0xFF1A6CE8);
  static const azulEscuro = Color(0xFF0846AB);
  static const azulClaro = Color(0xFFD3E3FD);
  static const azulSuave = Color(0xFFE8F0FE);
  static const ambar = Color(0xFFB06000);
  static const ambarClaro = Color(0xFFFEEFC3);
  static const textoAmbar = Color(0xFF6E3900);
  static const vermelho = Color(0xFFC5221F);
  static const vermelhoClaro = Color(0xFFFCE8E6);
  static const textoVermelho = Color(0xFF8C1D18);
  static const verde = Color(0xFF1E7E34);
  static const fundo = Color(0xFFFFFFFF);
  static const texto = Color(0xFF1A1C1E);
  static const textoSecundario = Color(0xFF5F6368);
  static const contorno = Color(0xFFDDE3EA);
  static const pista = Color(0xFFE3E8EF);

  // Escuro.
  static const azulEscuroTema = Color(0xFFA8C7FA);
  static const sobreAzulEscuroTema = Color(0xFF062E6F);
  static const azulClaroEscuro = Color(0xFF1F3A6B);
  static const ambarEscuro = Color(0xFFF6B26B);
  static const vermelhoEscuro = Color(0xFFF2B8B5);
  static const verdeEscuro = Color(0xFF6DD58C);
  static const fundoEscuro = Color(0xFF111418);
  static const cartaoEscuro = Color(0xFF1A1F27);
  static const textoEscuro = Color(0xFFE4E7EC);
  static const textoSecundarioEscuro = Color(0xFFA9B1BD);
  static const contornoEscuro = Color(0xFF2E3642);
}

/// Cores que o [ColorScheme] não tem: o gradiente do cabeçalho, o verde de
/// "dentro do limite" e a parte vazia das barras.
@immutable
class CoresCabaz extends ThemeExtension<CoresCabaz> {
  const CoresCabaz({
    required this.gradienteInicio,
    required this.gradienteFim,
    required this.sobreGradiente,
    required this.ok,
    required this.pista,
  });

  final Color gradienteInicio;
  final Color gradienteFim;

  /// Texto e ícones sobre o gradiente.
  final Color sobreGradiente;

  /// Dentro do limite, poupança.
  final Color ok;

  /// Parte vazia das barras.
  final Color pista;

  static const claro = CoresCabaz(
    gradienteInicio: Cores.azul,
    gradienteFim: Cores.azul2,
    sobreGradiente: Color(0xFFFFFFFF),
    ok: Cores.verde,
    pista: Cores.pista,
  );

  static const escuro = CoresCabaz(
    gradienteInicio: Color(0xFF0B3A8C),
    gradienteFim: Color(0xFF1250B8),
    sobreGradiente: Color(0xFFFFFFFF),
    ok: Cores.verdeEscuro,
    pista: Cores.contornoEscuro,
  );

  /// As cores do tema atual. Lança se o tema não as tiver (não falhar em
  /// silêncio com cores por omissão).
  static CoresCabaz of(BuildContext context) =>
      Theme.of(context).extension<CoresCabaz>() ??
      (throw StateError('O tema não tem CoresCabaz'));

  @override
  CoresCabaz copyWith({
    Color? gradienteInicio,
    Color? gradienteFim,
    Color? sobreGradiente,
    Color? ok,
    Color? pista,
  }) => CoresCabaz(
    gradienteInicio: gradienteInicio ?? this.gradienteInicio,
    gradienteFim: gradienteFim ?? this.gradienteFim,
    sobreGradiente: sobreGradiente ?? this.sobreGradiente,
    ok: ok ?? this.ok,
    pista: pista ?? this.pista,
  );

  @override
  CoresCabaz lerp(CoresCabaz? other, double t) {
    if (other == null) return this;
    return CoresCabaz(
      gradienteInicio: Color.lerp(gradienteInicio, other.gradienteInicio, t)!,
      gradienteFim: Color.lerp(gradienteFim, other.gradienteFim, t)!,
      sobreGradiente: Color.lerp(sobreGradiente, other.sobreGradiente, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      pista: Color.lerp(pista, other.pista, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoresCabaz &&
      other.gradienteInicio == gradienteInicio &&
      other.gradienteFim == gradienteFim &&
      other.sobreGradiente == sobreGradiente &&
      other.ok == ok &&
      other.pista == pista;

  @override
  int get hashCode =>
      Object.hash(gradienteInicio, gradienteFim, sobreGradiente, ok, pista);
}

ColorScheme _esquema(Brightness b) {
  if (b == Brightness.light) {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Cores.azul,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Cores.azulClaro,
      onPrimaryContainer: Cores.azulEscuro,
      secondary: Cores.azul2,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Cores.azulSuave,
      onSecondaryContainer: Cores.azulEscuro,
      tertiary: Cores.ambar,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Cores.ambarClaro,
      onTertiaryContainer: Cores.textoAmbar,
      error: Cores.vermelho,
      onError: Color(0xFFFFFFFF),
      errorContainer: Cores.vermelhoClaro,
      onErrorContainer: Cores.textoVermelho,
      surface: Cores.fundo,
      onSurface: Cores.texto,
      onSurfaceVariant: Cores.textoSecundario,
      surfaceContainerLowest: Cores.fundo,
      surfaceContainerLow: Cores.fundo,
      surfaceContainer: Color(0xFFF6F8FC),
      surfaceContainerHigh: Color(0xFFEEF2F8),
      surfaceContainerHighest: Cores.pista,
      outline: Color(0xFF8A94A3),
      outlineVariant: Cores.contorno,
      inverseSurface: Color(0xFF2E3135),
      onInverseSurface: Color(0xFFF1F3F6),
    );
  }
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: Cores.azulEscuroTema,
    onPrimary: Cores.sobreAzulEscuroTema,
    primaryContainer: Cores.azulClaroEscuro,
    onPrimaryContainer: Cores.azulClaro,
    secondary: Color(0xFF8AB4F8),
    onSecondary: Color(0xFF0B2A5C),
    secondaryContainer: Color(0xFF243A5E),
    onSecondaryContainer: Color(0xFFD6E3F7),
    tertiary: Cores.ambarEscuro,
    onTertiary: Color(0xFF3D2400),
    tertiaryContainer: Color(0xFF4A3216),
    onTertiaryContainer: Color(0xFFFFDDB3),
    error: Cores.vermelhoEscuro,
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF5C1714),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Cores.fundoEscuro,
    onSurface: Cores.textoEscuro,
    onSurfaceVariant: Cores.textoSecundarioEscuro,
    surfaceContainerLowest: Color(0xFF0C0F13),
    surfaceContainerLow: Cores.cartaoEscuro,
    surfaceContainer: Color(0xFF1E242C),
    surfaceContainerHigh: Color(0xFF252C36),
    surfaceContainerHighest: Cores.contornoEscuro,
    outline: Color(0xFF6F7A89),
    outlineVariant: Cores.contornoEscuro,
    inverseSurface: Cores.textoEscuro,
    onInverseSurface: Cores.texto,
  );
}

/// [fontesGoogle] é false nos testes (sem rede).
ThemeData construirTema(Brightness brilho, {bool fontesGoogle = true}) {
  final esquema = _esquema(brilho);
  final cores = brilho == Brightness.light
      ? CoresCabaz.claro
      : CoresCabaz.escuro;
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
    extensions: [cores],
    // Cabeçalho azul: a Pagina pinta o gradiente por cima; os ecrãs que
    // abrem por cima ficam com o azul sólido.
    appBarTheme: AppBarTheme(
      backgroundColor: cores.gradienteInicio,
      foregroundColor: cores.sobreGradiente,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: texto.titleLarge?.copyWith(color: cores.sobreGradiente),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: superficieCartao,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: esquema.surface,
      indicatorColor: esquema.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => texto.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : null,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
        ),
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: superficieCartao,
      indicatorColor: esquema.primaryContainer,
      indicatorShape: const StadiumBorder(),
      tileHeight: 52,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => texto.labelLarge?.copyWith(
          color: s.contains(WidgetState.selected)
              ? esquema.onPrimaryContainer
              : esquema.onSurface,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w500 : null,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? esquema.primary
              : esquema.onSurfaceVariant,
        ),
      ),
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
