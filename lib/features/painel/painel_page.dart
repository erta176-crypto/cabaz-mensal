import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../data/providers.dart';
import '../../domain/estatisticas.dart';
import '../../domain/modelos.dart';
import '../estatisticas/barras_horizontais.dart';
import '../estatisticas/cores.dart';
import '../estatisticas/grafico_meses.dart';
import '../artigos/ver_artigo.dart';
import '../shell/shell.dart';
import 'orcamento_cartao.dart';

final _hora = DateFormat('HH:mm', 'pt_PT');

/// Painel: totais do período e da loja escolhidos, calculados no servidor.
class PainelPage extends ConsumerStatefulWidget {
  const PainelPage({super.key});

  @override
  ConsumerState<PainelPage> createState() => _PainelPageState();
}

class _PainelPageState extends ConsumerState<PainelPage> {
  Periodo _periodo = Periodo.esteMes;
  String? _lojaId;

  FiltroCompras get _filtro => (periodo: _periodo, lojaId: _lojaId);

  @override
  Widget build(BuildContext context) {
    final painel = ref.watch(painelProvider(_filtro));
    final lojas = ref.watch(lojasProvider).value ?? const <Loja>[];

    return Pagina(
      titulo: 'Painel e estatísticas',
      corpo: RefreshIndicator(
        onRefresh: () async {
          try {
            ref.invalidate(painelProvider(_filtro));
            await ref.read(painelProvider(_filtro).future);
          } on Object {
            // O erro já aparece no ecrã através do provider.
          }
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _filtros(lojas),
                const SizedBox(height: 16),
                painel.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (erro, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('$erro', textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(painelProvider(_filtro)),
                          child: const Text('Tentar outra vez'),
                        ),
                      ],
                    ),
                  ),
                  data: (r) => _conteudo(r, lojas),
                ),
              ],
            ),
          ),
        ),
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
        ],
      );
    },
  );

  Widget _conteudo(ResultadoPainel r, List<Loja> lojas) {
    final d = r.dados;
    final guardadoEm = r.guardadoEm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (guardadoEm != null) _avisoCache(guardadoEm),
        _numeros(d),
        const SizedBox(height: 16),
        // O orçamento é do mês inteiro: só com "Este mês" e todas as lojas.
        if (_periodo == Periodo.esteMes && _lojaId == null) ...[
          OrcamentoCartao(gasto: d, hoje: DateTime.now()),
          const SizedBox(height: 16),
        ],
        if (d.nCompras == 0)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Não há compras neste período.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._seccoes(d, lojas),
      ],
    );
  }

  Widget _avisoCache(DateTime guardadoEm) {
    final esquema = Theme.of(context).colorScheme;
    final local = guardadoEm.toLocal();
    return Card(
      color: esquema.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.cloud_off, color: esquema.onTertiaryContainer),
        title: Text(
          'Dados de ${formatarData(local)} às ${_hora.format(local)}; '
          'sem rede.',
          style: TextStyle(color: esquema.onTertiaryContainer),
        ),
      ),
    );
  }

  Widget _numeros(DadosPainel d) {
    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        // 4 colunas se couberem com 160 px cada; senão 2, todas iguais.
        final colunas = c.maxWidth >= 4 * 160 + 3 * 8 ? 4 : 2;
        final largura = (c.maxWidth - (colunas - 1) * 8) / colunas;
        Widget cartao(String titulo, String valor, {Color? cor}) => SizedBox(
          width: largura,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      color: cor,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            cartao('Total gasto', formatarCent(d.totalCent)),
            cartao('Compras', formatarInteiro(d.nCompras)),
            cartao('Média por compra', formatarCent(d.mediaCent)),
            cartao(
              'Poupança',
              formatarCent(d.poupancaCent),
              cor: CoresCabaz.of(context).ok,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _seccoes(DadosPainel d, List<Loja> lojas) {
    final esquema = Theme.of(context).colorScheme;
    final intervalo = intervaloDe(_periodo, DateTime.now());
    final de = _periodo == Periodo.tudo && d.porMes.isNotEmpty
        ? d.porMes.first.mes
        : intervalo.de;
    final meses = mesesCompletos(d.porMes, de, intervalo.ate);

    final porId = {for (final l in lojas) l.id: l};
    final categorias = {
      for (final c
          in ref.watch(categoriasProvider).value ?? const <Categoria>[])
        c.id: c.nome,
    };
    final artigos = {
      for (final a in ref.watch(artigosProvider).value ?? const <Artigo>[])
        a.id: a,
    };
    final topo = categoriasTopo(d.porCategoria);

    final porLoja = _seccao(
      'Por loja',
      BarrasHorizontais(
        itens: [
          for (final t in d.porLoja)
            (
              rotulo: porId[t.lojaId]?.nome ?? 'Loja apagada',
              cent: t.totalCent,
              cor: porId[t.lojaId] == null
                  ? esquema.primary
                  : corDaLoja(porId[t.lojaId]!, esquema),
            ),
        ],
      ),
    );
    final porCategoria = _seccao(
      'Por categoria',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarrasHorizontais(
            itens: [
              for (final c in topo.topo)
                (
                  rotulo: c.categoriaId == null
                      ? 'Sem categoria'
                      : categorias[c.categoriaId] ?? 'Categoria apagada',
                  cent: c.totalCent,
                  cor: esquema.primary,
                ),
              if (topo.outrasCent > 0)
                (rotulo: 'Outras', cent: topo.outrasCent, cor: esquema.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Soma das linhas dos talões; pode diferir ligeiramente do total.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    return [
      if (meses.length > 1)
        _seccao('Gasto por mês', GraficoMeses(meses: meses)),
      if (_lojaId == null)
        // Lado a lado só se houver espaço (não basta o ecrã ser largo: o
        // menu fixo também ocupa largura).
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 700
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: porLoja),
                      const SizedBox(width: 8),
                      Expanded(child: porCategoria),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [porLoja, porCategoria],
                ),
        )
      else
        porCategoria,
      _seccao(
        'Artigos com mais gasto',
        Column(
          children: [
            for (final t in d.artigos)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(artigos[t.artigoId]?.nome ?? 'Artigo apagado'),
                subtitle: Text('${t.nLinhas}× comprado'),
                trailing: Text(formatarCent(t.totalCent)),
                onTap: artigos[t.artigoId] == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            DialogoVerArtigo(artigo: artigos[t.artigoId]!),
                      ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _seccao(String titulo, Widget conteudo) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          conteudo,
        ],
      ),
    ),
  );
}
