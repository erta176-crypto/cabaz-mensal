import 'package:flutter/material.dart';

import '../../domain/modelos.dart';

final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

/// Cor guardada na loja (`#rrggbb`, como grava o diálogo das lojas); null se
/// não tem cor ou o valor é inválido. Regra única da app.
Color? corDeHex(String? hex) => hex != null && _hex.hasMatch(hex)
    ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
    : null;

/// Cor da loja; sem cor ou com um valor inválido usa `primary`.
Color corDaLoja(Loja loja, ColorScheme esquema) =>
    corDeHex(loja.cor) ?? esquema.primary;
