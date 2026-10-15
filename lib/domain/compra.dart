/// Regras de "Concluir compra" e dos valores estimados da Lista.
/// Tudo em cêntimos inteiros; pesos em gramas.
library;

import 'dinheiro.dart';
import 'modelos.dart';

/// Valor estimado de uma linha da lista: quantidade × último preço.
/// Para artigos ao peso, [qtd] está em quilos e [precoCent] é o preço por kg.
int? valorEstimadoCent(Unidade unidade, num qtd, int? precoCent) {
  if (precoCent == null) return null;
  return switch (unidade) {
    Unidade.kg => (kgParaG(qtd) * precoCent / 1000).round(),
    Unidade.un => (qtd * precoCent).round(),
  };
}

class LinhaNova {
  const LinhaNova({
    required this.id,
    required this.precoId,
    required this.artigoId,
    required this.nome,
    required this.unidade,
    required this.precoUnitCent,
    this.quantidade,
    this.pesoG,
  });

  /// Ids gerados no cliente: repetir o envio não cria nada em duplicado.
  final String id;
  final String precoId;
  final String artigoId;
  final String nome;
  final Unidade unidade;

  /// Por unidade (un) ou por quilo (kg).
  final int precoUnitCent;
  final int? quantidade;
  final int? pesoG;

  int get valorCent => switch (unidade) {
    Unidade.kg => ((pesoG ?? 0) * precoUnitCent / 1000).round(),
    Unidade.un => (quantidade ?? 0) * precoUnitCent,
  };
}

class CompraNova {
  const CompraNova({
    required this.id,
    required this.lojaId,
    required this.local,
    required this.data,
    required this.linhas,
    this.totalTalaoCent,
  });

  final String id;
  final String lojaId;
  final String? local;
  final DateTime data;
  final List<LinhaNova> linhas;

  /// Total escrito pelo utilizador a partir do talão (opcional).
  final int? totalTalaoCent;

  int get totalCalculadoCent => linhas.fold(0, (s, l) => s + l.valorCent);

  /// O total da compra é o do talão quando existe; senão, o calculado.
  int get totalCent => totalTalaoCent ?? totalCalculadoCent;

  /// Diferença talão − calculado (0 sem talão).
  int get diferencaCent =>
      totalTalaoCent == null ? 0 : totalTalaoCent! - totalCalculadoCent;

  bool get rever => diferencaCent != 0;

  /// Payload da RPC concluir_compra. É sempre igual para a mesma compra.
  Map<String, dynamic> toPayload() => {
    'compra': {
      'id': id,
      'loja_id': lojaId,
      'local': local,
      'data': dataIso(data),
      'total_cent': totalCent,
      'poupanca_cent': 0,
      'rever': rever,
    },
    'linhas': [
      for (final l in linhas)
        {
          'id': l.id,
          'artigo_id': l.artigoId,
          'texto_original': l.nome,
          'quantidade': l.quantidade,
          'peso_g': l.pesoG,
          'preco_unit_cent': l.precoUnitCent,
          'bruto_cent': l.valorCent,
          'desconto_cent': 0,
          'pago_cent': l.valorCent,
        },
    ],
    'precos': [
      for (final l in linhas)
        {
          'id': l.precoId,
          'artigo_id': l.artigoId,
          'loja_id': lojaId,
          'data': dataIso(data),
          'preco_cent': l.precoUnitCent,
        },
    ],
    'itens': [
      for (final l in linhas) {'loja_id': lojaId, 'artigo_id': l.artigoId},
    ],
  };
}
