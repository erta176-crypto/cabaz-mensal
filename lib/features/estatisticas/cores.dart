import 'package:flutter/material.dart';

import '../../domain/modelos.dart';

final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

/// Cor da loja (`#rrggbb`); sem cor ou com um valor inválido usa `primary`.
Color corDaLoja(Loja loja, ColorScheme esquema) {
  final cor = loja.cor;
  if (cor == null || !_hex.hasMatch(cor)) return esquema.primary;
  return Color(0xFF000000 | int.parse(cor.substring(1), radix: 16));
}
