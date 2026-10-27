import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatos.dart';
import '../../import/taloes/importar_taloes.dart';

final _kg = NumberFormat('0.000', 'pt_PT');

/// Pré-visualização de uma importação de talões em PDF: um cartão por
/// talão (com o estado e as linhas) e a lista dos não reconhecidos.
class PrevisualizacaoTaloes extends StatelessWidget {
  const PrevisualizacaoTaloes({
    super.key,
    required this.taloes,
    required this.naoReconhecidos,
    required this.escolhas,
    required this.nomesArtigos,
    required this.online,
    required this.aGravar,
    required this.aoImportar,
    required this.aoCancelar,
    this.acoesLinha,
  });

  final List<TalaoAnalisado> taloes;
  final List<NaoReconhecido> naoReconhecidos;
  final Map<String, EscolhaArtigo> escolhas;

  /// Nome de cada artigo por id (para as linhas ligadas à mão).
  final Map<String, String> nomesArtigos;
  final bool online;
  final bool aGravar;
  final VoidCallback aoImportar;
  final VoidCallback aoCancelar;

  /// Ações de uma linha com artigo novo (ligar, mudar o nome, categoria).
  final Widget Function(TalaoAnalisado talao, LinhaAnalisada linha)? acoesLinha;

  int _contar(EstadoTalao e) => taloes.where((t) => t.estado == e).length;

  String get _resumo {
    String n(int c, String um, String varios) => '$c ${c == 1 ? um : varios}';
    final partes = [
      if (_contar(EstadoTalao.novo) > 0)
        n(_contar(EstadoTalao.novo), 'novo', 'novos'),
      if (_contar(EstadoTalao.aRever) > 0)
        n(_contar(EstadoTalao.aRever), 'a rever', 'a rever'),
      if (_contar(EstadoTalao.jaExiste) > 0)
        n(_contar(EstadoTalao.jaExiste), 'já importado', 'já importados'),
      if (_contar(EstadoTalao.repetidoNoLote) > 0)
        n(
          _contar(EstadoTalao.repetidoNoLote),
          'repetido neste lote',
          'repetidos neste lote',
        ),
    ];
    final resumo =
        '${n(taloes.length, 'talão', 'talões')}: ${partes.join(', ')}';
    return naoReconhecidos.isEmpty
        ? resumo
        : '$resumo · ${n(naoReconhecidos.length, 'não reconhecido', 'não reconhecidos')}';
  }

  String _artigoDa(TalaoAnalisado t, LinhaAnalisada l) =>
      switch (escolhas[chaveEscolha(t.loja.id, l.linha.texto)]) {
        LigarArtigo(:final artigoId) => nomesArtigos[artigoId] ?? '—',
        NovoArtigo(:final nome) => 'Novo: $nome',
        null => l.artigo?.nome ?? 'Novo: ${l.nomeNovo}',
      };

  String _quantidade(LinhaAnalisada l) => l.linha.pesoG != null
      ? '${_kg.format(l.linha.pesoG! / 1000)} kg'
      : '${l.linha.quantidade ?? 1} un';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aImportar = taloes.where((t) => t.estado.importa).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Talões (PDF)', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_resumo),
            const SizedBox(height: 12),
            for (final t in taloes) _talao(context, t),
            if (naoReconhecidos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Não reconhecidos', style: tema.textTheme.titleSmall),
              for (final n in naoReconhecidos)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${n.ficheiro}: ${n.motivo}',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
            ],
            if (!online) ...[
              const SizedBox(height: 12),
              Text(
                'Sem rede: a importação de talões precisa do servidor.',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: aGravar ? null : aoCancelar,
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: aImportar == 0 || !online || aGravar
                      ? null
                      : aoImportar,
                  child: Text(
                    'Importar $aImportar ${aImportar == 1 ? 'talão' : 'talões'}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _talao(BuildContext context, TalaoAnalisado t) {
    final tema = Theme.of(context);
    final cor = switch (t.estado) {
      EstadoTalao.novo => tema.colorScheme.primary,
      EstadoTalao.aRever => tema.colorScheme.error,
      _ => tema.colorScheme.onSurfaceVariant,
    };
    return ExpansionTile(
      key: PageStorageKey('talao-${t.ficheiro}'),
      initiallyExpanded: t.estado.importa,
      tilePadding: EdgeInsets.zero,
      title: Text(t.talao.local ?? t.loja.nome),
      subtitle: Text(
        '${formatarData(t.talao.data)} · ${formatarCent(t.talao.totalCent)} · '
        '${t.estado.rotulo}',
        style: TextStyle(color: cor),
      ),
      children: [
        for (final l in t.linhas)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l.linha.texto),
            subtitle: Text('${_quantidade(l)} · ${_artigoDa(t, l)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatarCent(l.pagoCent)),
                if (acoesLinha != null) acoesLinha!(t, l),
              ],
            ),
          ),
      ],
    );
  }
}
