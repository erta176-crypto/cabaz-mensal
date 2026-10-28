import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Filtro do cabeçalho: pílula branca com ícone, valor atual e ▾; abre um
/// menu com as [opcoes]. O [rotulo] só é lido pelo leitor de ecrã e na dica.
class FiltroPilula<T> extends StatefulWidget {
  const FiltroPilula({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.valor,
    required this.opcoes,
    required this.aoMudar,
  });

  final String rotulo;
  final IconData icone;
  final T valor;

  /// Valor → texto, pela ordem do menu (o valor pode ser null, ex.: "Todas").
  final Map<T, String> opcoes;
  final ValueChanged<T> aoMudar;

  @override
  State<FiltroPilula<T>> createState() => _FiltroPilulaState<T>();
}

class _FiltroPilulaState<T> extends State<FiltroPilula<T>> {
  // O menu usa índices: um item com valor null contaria como "cancelar".
  final _menu = GlobalKey<PopupMenuButtonState<int>>();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = CoresCabaz.of(context);
    final valores = widget.opcoes.keys.toList();
    final texto = widget.opcoes[widget.valor] ?? '';
    return Semantics(
      button: true,
      label: '${widget.rotulo}: $texto',
      excludeSemantics: true,
      onTap: () => _menu.currentState?.showButtonMenu(),
      child: PopupMenuButton<int>(
        key: _menu,
        tooltip: widget.rotulo,
        initialValue: valores.indexOf(widget.valor),
        onSelected: (i) => widget.aoMudar(valores[i]),
        itemBuilder: (_) => [
          for (var i = 0; i < valores.length; i++)
            PopupMenuItem(value: i, child: Text(widget.opcoes[valores[i]]!)),
        ],
        // Área de toque de 48 px à volta da pílula de 40.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: ShapeDecoration(
              color: cores.fundoFiltro,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icone, size: 18, color: cores.gradienteInicio),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: cores.textoFiltro,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: cores.textoFiltro),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pesquisa do cabeçalho: campo branco arredondado com lupa.
class CampoPesquisa extends StatelessWidget {
  const CampoPesquisa({
    super.key,
    required this.dica,
    required this.aoEscrever,
    this.aoSubmeter,
  });

  final String dica;
  final ValueChanged<String> aoEscrever;
  final ValueChanged<String>? aoSubmeter;

  @override
  Widget build(BuildContext context) {
    final cores = CoresCabaz.of(context);
    const forma = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      borderSide: BorderSide.none,
    );
    return TextField(
      style: TextStyle(color: cores.textoFiltro),
      cursorColor: cores.gradienteInicio,
      decoration: InputDecoration(
        hintText: dica,
        hintStyle: TextStyle(color: cores.textoFiltro.withValues(alpha: 0.7)),
        prefixIcon: Icon(Icons.search, color: cores.textoFiltro),
        filled: true,
        fillColor: cores.fundoFiltro,
        isDense: true,
        border: forma,
        enabledBorder: forma,
        focusedBorder: forma,
      ),
      textInputAction: TextInputAction.search,
      onChanged: aoEscrever,
      onSubmitted: aoSubmeter,
    );
  }
}
