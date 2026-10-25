/// Exportação de uma cópia completa em JSON, no mesmo formato (versão 2) do
/// cabaz-seed.json, para poder ser importada outra vez.
library;

import 'dart:convert';

import '../domain/modelos.dart';

/// [tabelas] são as linhas em bruto de cada tabela (DadosRepository.lerTudo).
Map<String, dynamic> montarExportacao(
  Map<String, List<Map<String, dynamic>>> tabelas, {
  DateTime? agora,
}) {
  // O que está apagado (apagado_em) não entra na cópia. As linhas de compra
  // de um artigo apagado ficam sem artigo (mantêm o texto do talão).
  List<Map<String, dynamic>> t(String nome) => [
    for (final l in tabelas[nome] ?? const <Map<String, dynamic>>[])
      if (l['apagado_em'] == null) l,
  ];
  final artigosAtivos = {for (final a in t('artigos')) a['id']};
  final categoriasAtivas = {for (final c in t('categorias')) c['id']};
  Object? artigo(Object? id) => artigosAtivos.contains(id) ? id : null;

  // As lojas são identificadas pelo slug, como no ficheiro original.
  final slugPorLoja = {
    for (final l in t('lojas')) l['id'] as String: l['slug'] as String,
  };
  String slug(Object? lojaId) => slugPorLoja[lojaId] ?? '$lojaId';

  final compras = [...t('compras')]
    ..sort((a, b) => (a['data'] as String).compareTo(b['data'] as String));

  final totalPorLoja = <String, int>{};
  var total = 0;
  for (final c in compras) {
    final v = (c['total_cent'] as num).toInt();
    total += v;
    totalPorLoja.update(slug(c['loja_id']), (s) => s + v, ifAbsent: () => v);
  }

  // Os preços 'talao' são recriados a partir das linhas na importação.
  final precos = t('registos_preco')
      .where((p) => p['origem'] != 'talao' && artigo(p['artigo_id']) != null);

  return {
    'versao': 2,
    'gerado_em': dataIso(agora ?? DateTime.now()),
    'moeda': 'EUR',
    'lojas': [
      for (final l in t('lojas'))
        {
          'id': l['slug'],
          'nome': l['nome'],
          'cor': l['cor'],
          'cadeia': l['cadeia'],
          'local': l['local'],
        },
    ],
    'categorias': [
      for (final c in t('categorias'))
        {'id': c['id'], 'nome': c['nome'], 'ordem': c['ordem']},
    ],
    'artigos': [
      for (final a in t('artigos'))
        {
          'id': a['id'],
          'nome': a['nome'],
          'categoria_id': categoriasAtivas.contains(a['categoria_id'])
              ? a['categoria_id']
              : null,
          'unidade': a['unidade'],
          'ean': a['ean'],
        },
    ],
    'aliases': [
      for (final a in t('aliases'))
        if (artigo(a['artigo_id']) != null)
          {
            'artigo_id': a['artigo_id'],
            'loja_id': slug(a['loja_id']),
            'texto': a['texto_talao'],
          },
    ],
    'compras': [
      for (final c in compras)
        {
          'id': c['id'],
          'loja_id': slug(c['loja_id']),
          'local': c['local'],
          'data': c['data'],
          'total_cent': c['total_cent'],
          'origem': c['origem'],
          'ficheiro': c['ficheiro'],
        },
    ],
    'linhas': [
      for (final l in t('linhas_compra'))
        {
          'compra_id': l['compra_id'],
          'artigo_id': artigo(l['artigo_id']),
          'texto_original': l['texto_original'],
          'quantidade': l['quantidade'],
          'peso_kg': l['peso_g'] == null
              ? null
              : (l['peso_g'] as num).toInt() / 1000,
          'bruto_cent': l['bruto_cent'],
          'desconto_cent': l['desconto_cent'],
          'pago_cent': l['pago_cent'],
        },
    ],
    'listas': [
      for (final i in t('itens_lista'))
        if (artigo(i['artigo_id']) != null)
          {
            'loja_id': slug(i['loja_id']),
            'artigo_id': i['artigo_id'],
            'quantidade_padrao': i['qtd_padrao'],
            'incluido': i['incluido'],
          },
    ],
    'precos': [
      for (final p in precos)
        {
          'artigo_id': p['artigo_id'],
          'loja_id': slug(p['loja_id']),
          'data': p['data'],
          'preco_cent': p['preco_cent'],
          'origem': p['origem'],
        },
    ],
    'controlo': {
      'compras': compras.length,
      'linhas': t('linhas_compra').length,
      'artigos': t('artigos').length,
      'categorias': t('categorias').length,
      'aliases': t('aliases').length,
      'itens_lista': t('itens_lista').length,
      'precos': precos.length,
      'total_cent': total,
      'total_por_loja_cent': totalPorLoja,
    },
  };
}

String exportacaoParaTexto(Map<String, dynamic> dados) =>
    const JsonEncoder.withIndent(' ').convert(dados);
