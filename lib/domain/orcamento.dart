/// Orçamento mensal: total do mês e, opcionalmente, por categoria.
/// Dinheiro em cêntimos inteiros.
library;

import 'package:uuid/uuid.dart';

import 'estatisticas.dart';
import 'modelos.dart';

/// Espaço de nomes fixo dos ids de orçamento (uuid v5). Não mudar: os ids
/// já gravados deixariam de bater.
const _espacoNomes = '6b1f3c3e-9a7d-4f21-8c55-0d2e7a9b4c10';

class Orcamento {
  const Orcamento({
    required this.id,
    required this.mes,
    this.categoriaId,
    required this.valorCent,
  });

  final String id;

  /// Dia 1 do mês.
  final DateTime mes;

  /// null = orçamento total do mês.
  final String? categoriaId;
  final int valorCent;

  factory Orcamento.fromMap(Map<String, dynamic> m) => Orcamento(
    id: m['id'] as String,
    mes: DateTime.parse(m['mes'] as String),
    categoriaId: m['categoria_id'] as String?,
    valorCent: (m['valor_cent'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'mes': dataIso(mes),
    'categoria_id': categoriaId,
    'valor_cent': valorCent,
  };
}

/// Id determinístico (uuid v5) do orçamento de [categoriaId] (null = total)
/// no mês de [mes]. Dois aparelhos que criam o mesmo orçamento sem rede geram
/// o mesmo id, e o upsert junta-os (decisão 0009).
String idOrcamento(String userId, DateTime mes, String? categoriaId) {
  final aaaaMm =
      '${mes.year.toString().padLeft(4, '0')}-'
      '${mes.month.toString().padLeft(2, '0')}';
  return const Uuid().v5(
    _espacoNomes,
    '$userId|$aaaaMm|${categoriaId ?? 'total'}',
  );
}

/// Estado de um gasto face ao orçamento.
enum NivelOrcamento { ok, quase, passou }

/// ok abaixo de 80 %, quase de 80 % a 100 %, passou acima de 100 %.
NivelOrcamento nivel(int gastoCent, int orcamentoCent) {
  if (gastoCent > orcamentoCent) return NivelOrcamento.passou;
  if (gastoCent * 100 >= orcamentoCent * 80 && orcamentoCent > 0) {
    return NivelOrcamento.quase;
  }
  return NivelOrcamento.ok;
}

/// Linha do cartão do orçamento. [faltaCent] negativo = passou.
typedef LinhaOrcamento = ({
  String? categoriaId,
  int orcamentoCent,
  int gastoCent,
  int faltaCent,
  NivelOrcamento nivel,
});

/// Percentagem gasta, arredondada (491 de 400 → 123); null sem orçamento.
int? percentagemGasta(LinhaOrcamento l) =>
    l.orcamentoCent <= 0 ? null : (l.gastoCent * 100 / l.orcamentoCent).round();

LinhaOrcamento _linha(String? categoriaId, int orcamentoCent, int gastoCent) =>
    (
      categoriaId: categoriaId,
      orcamentoCent: orcamentoCent,
      gastoCent: gastoCent,
      faltaCent: orcamentoCent - gastoCent,
      nivel: nivel(gastoCent, orcamentoCent),
    );

/// Junta os orçamentos de um mês com o gasto desse mês (do Painel).
/// Categorias com gasto mas sem orçamento não entram.
({LinhaOrcamento? total, List<LinhaOrcamento> categorias}) compararOrcamento(
  List<Orcamento> doMes,
  DadosPainel gasto,
) {
  final porCategoria = {
    for (final c in gasto.porCategoria) c.categoriaId: c.totalCent,
  };
  final total = doMes.where((o) => o.categoriaId == null).firstOrNull;
  return (
    total: total == null
        ? null
        : _linha(null, total.valorCent, gasto.totalCent),
    categorias: [
      for (final o in doMes)
        if (o.categoriaId != null)
          _linha(o.categoriaId, o.valorCent, porCategoria[o.categoriaId] ?? 0),
    ],
  );
}
