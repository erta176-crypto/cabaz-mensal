import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../estatisticas/cores.dart';
import '../shell/shell.dart';
import 'detalhe_compra.dart';
import 'pesquisa.dart';

final _mes = DateFormat("MMMM 'de' y", 'pt_PT');

/// Chave do histórico. Os ids dos artigos vão juntos num texto porque as
/// listas não têm igualdade de valor.
typedef _ChaveHistorico = ({
  FiltroCompras filtro,
  String artigosChave,
  String? texto,
});

final _comprasHistoricoProvider = FutureProvider.autoDispose
    .family<List<CompraResumo>, _ChaveHistorico>(
      (ref, c) => ref
          .watch(estatisticasRepositoryProvider)
          .compras(
            c.filtro,
            artigoIds: c.artigosChave.isEmpty
                ? null
                : c.artigosChave.split(','),
            texto: c.texto,
          ),
    );

/// Histórico: compras antigas, só para consulta (precisa de rede).
class HistoricoPage extends ConsumerStatefulWidget {
  const HistoricoPage({super.key});

  @override
  ConsumerState<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends ConsumerState<HistoricoPage> {
  Periodo _periodo = Periodo.ultimos12Meses;
  String? _lojaId;
  String _pesquisa = '';
  Timer? _espera;
  String? _selecionada;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  void _escrever(String v) {
    _espera?.cancel();
    _espera = Timer(
      const Duration(milliseconds: 400),
      () => setState(() => _pesquisa = v),
    );
  }

  void _submeter(String v) {
    _espera?.cancel();
    setState(() => _pesquisa = v);
  }

  _ChaveHistorico _chave() {
    final termos = termosPesquisa(
      _pesquisa,
      ref.watch(artigosProvider).value ?? const [],
      ref.watch(aliasesProvider).value ?? const {},
    );
    return (
      filtro: (periodo: _periodo, lojaId: _lojaId),
      artigosChave: termos.artigoIds.join(','),
      texto: termos.texto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lojas = ref.watch(lojasProvider).value ?? const <Loja>[];
    final chave = _chave();
    final compras = ref.watch(_comprasHistoricoProvider(chave));
    final largo = MediaQuery.sizeOf(context).width >= larguraEcraLargo;

    final lista = compras.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$erro', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(_comprasHistoricoProvider(chave)),
                child: const Text('Tentar outra vez'),
              ),
            ],
          ),
        ),
      ),
      data: (c) => _lista(c, lojas, largo),
    );

    final selecionada = compras.value
        ?.where((c) => c.id == _selecionada)
        .firstOrNull;

    return Pagina(
      titulo: 'Histórico',
      corpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _filtros(lojas)),
          Expanded(
            child: largo
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 420, child: lista),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: selecionada == null
                            ? const Center(child: Text('Escolhe uma compra.'))
                            : DetalheCompra(
                                key: ValueKey(selecionada.id),
                                compra: selecionada,
                              ),
                      ),
                    ],
                  )
                : lista,
          ),
        ],
      ),
    );
  }

  Widget _filtros(List<Loja> lojas) => LayoutBuilder(
    builder: (context, c) {
      final largura = c.maxWidth < 600 ? c.maxWidth : 260.0;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(
            width: largura,
            child: DropdownButtonFormField<Periodo>(
              initialValue: _periodo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Período'),
              items: [
                for (final p in Periodo.values)
                  DropdownMenuItem(value: p, child: Text(p.rotulo)),
              ],
              onChanged: (p) => setState(() => _periodo = p ?? _periodo),
            ),
          ),
          SizedBox(
            width: largura,
            child: DropdownButtonFormField<String?>(
              // A chave reconstrói o menu quando as lojas chegam.
              key: ValueKey(lojas.length),
              initialValue: lojas.any((l) => l.id == _lojaId) ? _lojaId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loja'),
              items: [
                const DropdownMenuItem(child: Text('Todas as lojas')),
                for (final l in lojas)
                  DropdownMenuItem(value: l.id, child: Text(l.nome)),
              ],
              onChanged: (id) => setState(() => _lojaId = id),
            ),
          ),
          SizedBox(
            width: largura,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Pesquisar',
                hintText: 'Artigo ou texto do talão',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onChanged: _escrever,
              onSubmitted: _submeter,
            ),
          ),
        ],
      );
    },
  );

  Widget _lista(List<CompraResumo> compras, List<Loja> lojas, bool largo) {
    if (compras.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _pesquisa.trim().isEmpty
                ? 'Não há compras neste período.'
                : 'Nenhuma compra encontrada.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final tema = Theme.of(context);
    final porId = {for (final l in lojas) l.id: l};

    return CustomScrollView(
      slivers: [
        for (final g in porMes(compras)) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _Cabecalho(
              '${_mes.format(g.mes)} · ${g.compras.length} '
              '${g.compras.length == 1 ? 'compra' : 'compras'} · '
              '${formatarCent(g.totalCent)}',
              tema,
            ),
          ),
          SliverList.list(
            children: [
              for (final c in g.compras)
                _linhaCompra(c, porId[c.lojaId], largo),
            ],
          ),
        ],
      ],
    );
  }

  Widget _linhaCompra(CompraResumo c, Loja? loja, bool largo) {
    final esquema = Theme.of(context).colorScheme;
    return ListTile(
      selected: largo && c.id == _selecionada,
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: loja == null
            ? esquema.primary
            : corDaLoja(loja, esquema),
      ),
      title: Text([loja?.nome ?? 'Loja apagada', ?c.local].join(' · ')),
      subtitle: Text(
        '${formatarData(c.data)} · ${c.nLinhas} artigos'
        '${c.poupancaCent > 0 ? ' · poupou ${formatarCent(c.poupancaCent)}' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.rever)
            Tooltip(
              message: avisoRever,
              child: Icon(Icons.error_outline, color: esquema.error),
            ),
          const SizedBox(width: 4),
          Text(formatarCent(c.totalCent)),
        ],
      ),
      onTap: () {
        if (largo) {
          setState(() => _selecionada = c.id);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetalheCompraPage(compra: c),
            ),
          );
        }
      },
    );
  }
}

/// Cabeçalho do mês, fixo no topo enquanto se percorre esse mês.
class _Cabecalho extends SliverPersistentHeaderDelegate {
  _Cabecalho(this.texto, this.tema);

  final String texto;
  final ThemeData tema;

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(
        color: tema.colorScheme.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          texto,
          style: tema.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  @override
  bool shouldRebuild(_Cabecalho old) => old.texto != texto || old.tema != tema;
}
