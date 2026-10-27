import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Fora da web não há arrastar e largar: fica só o botão "Escolher ficheiro".
class ZonaLargar extends StatelessWidget {
  const ZonaLargar({
    super.key,
    required this.aoLargar,
    this.aoLargarVarios,
    required this.child,
  });

  final void Function(String nome, Uint8List bytes) aoLargar;

  /// Se existir, recebe todos os ficheiros largados de uma vez.
  final void Function(List<({String nome, Uint8List bytes})> ficheiros)?
  aoLargarVarios;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
