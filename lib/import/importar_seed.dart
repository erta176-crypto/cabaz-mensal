/// Importação do histórico (cabaz-seed.json) para o Supabase.
///
/// 1. [SeedFicheiro.lerTexto] valida o ficheiro.
/// 2. [montarPayload] converte-o no JSON enviado à RPC importar_seed:
///    UUIDs novos, chaves estrangeiras resolvidas, pesos em gramas, preço
///    unitário, poupança e marca "rever".
/// 3. A RPC insere tudo numa só transação (tudo-ou-nada).
/// 4. [verificarControlo] compara o resultado com os totais do ficheiro.
library;

import 'package:uuid/uuid.dart';

import '../data/repositorios.dart';
import '../domain/dinheiro.dart';
import '../domain/modelos.dart';
import 'seed_modelo.dart';

class PayloadImportacao {
  const PayloadImportacao({
    required this.lojas,
    required this.categorias,
    required this.artigos,
    required this.aliases,
    required this.compras,
    required this.linhas,
    required this.registosPreco,
    required this.itensLista,
  });

  final List<Loja> lojas;
  final List<Categoria> categorias;
  final List<Artigo> artigos;
  final List<Alias> aliases;
  final List<Compra> compras;
  final List<LinhaCompra> linhas;
  final List<RegistoPreco> registosPreco;
  final List<ItemLista> itensLista;

  int get comprasRever => compras.where((c) => c.rever).length;
  int get totalCent => compras.fold(0, (s, c) => s + c.totalCent);

  Map<String, dynamic> toJson() => {
    'lojas': [for (final x in lojas) x.toMap()],
    'categorias': [for (final x in categorias) x.toMap()],
    'artigos': [for (final x in artigos) x.toMap()],
    'aliases': [for (final x in aliases) x.toMap()],
    'compras': [for (final x in compras) x.toMap()],
    'linhas_compra': [for (final x in linhas) x.toMap()],
    'registos_preco': [for (final x in registosPreco) x.toMap()],
    'itens_lista': [for (final x in itensLista) x.toMap()],
  };
}

/// Converte o ficheiro validado no payload da RPC. [novoId] permite ids
/// previsíveis nos testes.
PayloadImportacao montarPayload(SeedFicheiro f, {String Function()? novoId}) {
  final gerar = novoId ?? const Uuid().v4;
  final idLoja = {for (final l in f.lojas) l.id: gerar()};
  final idCategoria = {for (final c in f.categorias) c.id: gerar()};
  final idArtigo = {for (final a in f.artigos) a.id: gerar()};
  final idCompra = {for (final c in f.compras) c.id: gerar()};
  final compraPorId = {for (final c in f.compras) c.id: c};

  final lojas = [
    for (final l in f.lojas)
      Loja(
        id: idLoja[l.id]!,
        slug: l.id,
        nome: l.nome,
        cadeia: l.cadeia ?? l.nome,
        local: l.local,
        cor: l.cor,
      ),
  ];

  final categorias = [
    for (final c in f.categorias)
      Categoria(id: idCategoria[c.id]!, nome: c.nome, ordem: c.ordem),
  ];

  final artigos = [
    for (final a in f.artigos)
      Artigo(
        id: idArtigo[a.id]!,
        nome: a.nome,
        categoriaId: a.categoriaId == null ? null : idCategoria[a.categoriaId],
        unidade: Unidade.deCodigo(a.unidade),
      ),
  ];

  final aliases = [
    for (final a in f.aliases)
      Alias(
        id: gerar(),
        artigoId: idArtigo[a.artigoId]!,
        lojaId: idLoja[a.lojaId]!,
        textoTalao: a.texto,
      ),
  ];

  // Somas por compra, sempre em cêntimos inteiros.
  final pagoPorCompra = <String, int>{};
  final descontoPorCompra = <String, int>{};
  for (final l in f.linhas) {
    pagoPorCompra.update(
      l.compraId,
      (v) => v + l.pagoCent,
      ifAbsent: () => l.pagoCent,
    );
    descontoPorCompra.update(
      l.compraId,
      (v) => v + l.descontoCent,
      ifAbsent: () => l.descontoCent,
    );
  }

  final compras = [
    for (final c in f.compras)
      Compra(
        id: idCompra[c.id]!,
        lojaId: idLoja[c.lojaId]!,
        local: c.local,
        data: c.data,
        totalCent: c.totalCent,
        poupancaCent: descontoPorCompra[c.id] ?? 0,
        origem: OrigemCompra.values.byName(c.origem),
        ficheiro: c.ficheiro,
        rever: compraARever(
          totalCent: c.totalCent,
          somaLinhasCent: pagoPorCompra[c.id] ?? 0,
        ),
      ),
  ];

  final linhas = <LinhaCompra>[];
  final registos = <RegistoPreco>[];
  for (final l in f.linhas) {
    final pesoG = l.pesoKg == null ? null : kgParaG(l.pesoKg!);
    final precoUnit = precoUnitarioCent(
      brutoCent: l.brutoCent,
      quantidade: l.quantidade,
      pesoG: pesoG,
    );
    final artigoId = l.artigoId == null ? null : idArtigo[l.artigoId];
    linhas.add(
      LinhaCompra(
        id: gerar(),
        compraId: idCompra[l.compraId]!,
        artigoId: artigoId,
        textoOriginal: l.textoOriginal,
        quantidade: l.quantidade,
        pesoG: pesoG,
        precoUnitCent: precoUnit,
        brutoCent: l.brutoCent,
        descontoCent: l.descontoCent,
        pagoCent: l.pagoCent,
      ),
    );
    // Um registo de preço por linha (origem 'talao').
    if (artigoId != null && precoUnit != null) {
      final compra = compraPorId[l.compraId]!;
      registos.add(
        RegistoPreco(
          id: gerar(),
          artigoId: artigoId,
          lojaId: idLoja[compra.lojaId]!,
          data: compra.data,
          precoCent: precoUnit,
          origem: OrigemPreco.talao,
        ),
      );
    }
  }
  for (final p in f.precos) {
    registos.add(
      RegistoPreco(
        id: gerar(),
        artigoId: idArtigo[p.artigoId]!,
        lojaId: idLoja[p.lojaId]!,
        data: p.data,
        precoCent: p.precoCent,
        origem: OrigemPreco.values.byName(p.origem),
      ),
    );
  }

  final itens = [
    for (final i in f.listas)
      ItemLista(
        id: gerar(),
        lojaId: idLoja[i.lojaId]!,
        artigoId: idArtigo[i.artigoId]!,
        qtdPadrao: i.quantidadePadrao,
        incluido: i.incluido,
      ),
  ];

  return PayloadImportacao(
    lojas: lojas,
    categorias: categorias,
    artigos: artigos,
    aliases: aliases,
    compras: compras,
    linhas: linhas,
    registosPreco: registos,
    itensLista: itens,
  );
}

/// Uma compra cuja soma das linhas não bate com o total fica para rever
/// (não é rejeitada).
bool compraARever({required int totalCent, required int somaLinhasCent}) =>
    totalCent != somaLinhasCent;

class VerificacaoLoja {
  const VerificacaoLoja({
    required this.slug,
    required this.nome,
    required this.nCompras,
    required this.totalCent,
    required this.esperadoCent,
  });

  final String slug;
  final String nome;
  final int nCompras;
  final int totalCent;

  /// null se o ficheiro não trouxer total de controlo para esta loja.
  final int? esperadoCent;

  bool? get ok => esperadoCent == null ? null : esperadoCent == totalCent;
}

class ResultadoImportacao {
  const ResultadoImportacao({
    required this.contagens,
    required this.lojas,
    required this.totalCent,
    required this.totalEsperadoCent,
    required this.comprasRever,
  });

  final ContagensImportacao contagens;
  final List<VerificacaoLoja> lojas;
  final int totalCent;
  final int? totalEsperadoCent;
  final int comprasRever;

  bool? get totalOk =>
      totalEsperadoCent == null ? null : totalEsperadoCent == totalCent;

  bool get tudoOk => totalOk != false && lojas.every((l) => l.ok != false);
}

/// Compara o resumo do servidor (view resumo_por_loja) com os totais de
/// controlo do ficheiro.
List<VerificacaoLoja> verificarControlo(
  SeedControlo? controlo,
  List<ResumoLoja> resumo,
) {
  final esperado = controlo?.totalPorLojaCent ?? const <String, int>{};
  final vistos = <String>{};
  final r = <VerificacaoLoja>[
    for (final l in resumo)
      if (vistos.add(l.slug))
        VerificacaoLoja(
          slug: l.slug,
          nome: l.nome,
          nCompras: l.nCompras,
          totalCent: l.totalCent,
          esperadoCent: esperado[l.slug],
        ),
  ];
  // Lojas que o controlo menciona mas que não chegaram ao servidor.
  for (final MapEntry(:key, :value) in esperado.entries) {
    if (!vistos.contains(key)) {
      r.add(
        VerificacaoLoja(
          slug: key,
          nome: key,
          nCompras: 0,
          totalCent: 0,
          esperadoCent: value,
        ),
      );
    }
  }
  return r;
}

/// Orquestra a importação. Recebe os repositórios para poder ser testada
/// com versões em memória.
class ImportadorSeed {
  ImportadorSeed({required this.dados, this.novoId});

  final DadosRepository dados;
  final String Function()? novoId;

  Future<ResultadoImportacao> importar(
    SeedFicheiro ficheiro, {
    required bool substituir,
  }) async {
    final payload = montarPayload(ficheiro, novoId: novoId);
    final contagens = await dados.importar(
      payload.toJson(),
      substituir: substituir,
    );
    final resumo = await dados.resumoPorLoja();
    return ResultadoImportacao(
      contagens: contagens,
      lojas: verificarControlo(ficheiro.controlo, resumo),
      totalCent: contagens['total_cent'],
      totalEsperadoCent: ficheiro.controlo?.totalCent,
      comprasRever: contagens['compras_rever'],
    );
  }
}
