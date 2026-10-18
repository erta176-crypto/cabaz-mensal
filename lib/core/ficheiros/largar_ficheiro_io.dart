import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Fora da web não há arrastar e largar: fica só o botão "Escolher ficheiro".
class ZonaLargar extends StatelessWidget {
  const ZonaLargar({super.key, required this.aoLargar, required this.child});

  final void Function(String nome, Uint8List bytes) aoLargar;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
