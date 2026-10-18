import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Na web, aceita um ficheiro largado em qualquer ponto da janela enquanto
/// este widget estiver visível, e realça o [child] durante o arrasto.
class ZonaLargar extends StatefulWidget {
  const ZonaLargar({super.key, required this.aoLargar, required this.child});

  final void Function(String nome, Uint8List bytes) aoLargar;
  final Widget child;

  @override
  State<ZonaLargar> createState() => _ZonaLargarState();
}

class _ZonaLargarState extends State<ZonaLargar> {
  bool _aArrastar = false;
  late final JSFunction _sobre = ((web.DragEvent e) {
    e.preventDefault();
    if (!_aArrastar) setState(() => _aArrastar = true);
  }).toJS;
  late final JSFunction _sair = ((web.DragEvent e) {
    if (e.relatedTarget == null) setState(() => _aArrastar = false);
  }).toJS;
  late final JSFunction _largar = ((web.DragEvent e) {
    e.preventDefault();
    setState(() => _aArrastar = false);
    final ficheiros = e.dataTransfer?.files;
    if (ficheiros == null || ficheiros.length == 0) return;
    final f = ficheiros.item(0)!;
    f.arrayBuffer().toDart.then(
      (b) => widget.aoLargar(f.name, b.toDart.asUint8List()),
    );
  }).toJS;

  @override
  void initState() {
    super.initState();
    web.window
      ..addEventListener('dragover', _sobre)
      ..addEventListener('dragleave', _sair)
      ..addEventListener('drop', _largar);
  }

  @override
  void dispose() {
    web.window
      ..removeEventListener('dragover', _sobre)
      ..removeEventListener('dragleave', _sair)
      ..removeEventListener('drop', _largar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _aArrastar ? cores.primary : Colors.transparent,
          width: 2,
        ),
        color: _aArrastar
            ? cores.primaryContainer.withValues(alpha: 0.4)
            : null,
      ),
      child: widget.child,
    );
  }
}
