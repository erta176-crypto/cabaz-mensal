/// Dos talões lidos ao lote da RPC importar_lote, com a mesma convenção dos
/// talões já importados: total = o que se pagou, descontos da compra
/// repartidos pelas linhas, origem 'importacao' (decisão D6 da Fase 5).
library;

import '../../domain/modelos.dart';
import '../../domain/texto.dart';
import '../analise_comum.dart';
import '../previsualizacao.dart';
import 'ler_talao.dart';
import 'seccoes.dart';
import 'talao.dart';

enum EstadoTalao {
  novo('Novo'),
  jaExiste('Já importado'),
  repetidoNoLote('Repetido neste lote'),
  aRever('A rever: a soma das linhas não bate com o total');

  const EstadoTalao(this.rotulo);
  final String rotulo;

  /// Entra no lote (os "a rever" entram com a compra marcada para rever).
  bool get importa => this == novo || this == aRever;
}

class LinhaAnalisada {
  const LinhaAnalisada({
    required this.linha,
    required this.descontoTotalCent,
    required this.artigo,
    required this.nomeNovo,
    this.categoriaSugerida,
  });

  final LinhaTalao linha;

  /// Desconto do próprio artigo mais a parte do desconto da compra.
  final int descontoTotalCent;

  /// Artigo encontrado pelo nome ou alias; null = artigo novo.
  final Artigo? artigo;

  /// Nome do artigo novo: o texto com só a 1.ª letra maiúscula.
  final String nomeNovo;

  /// Id da categoria sugerida pela secção do talão (para um artigo novo).
  final String? categoriaSugerida;

  int get pagoCent => linha.brutoCent - descontoTotalCent;
}

class TalaoAnalisado {
  const TalaoAnalisado({
    required this.ficheiro,
    required this.talao,
    required this.loja,
    required this.estado,
    required this.linhas,
  });

  final String ficheiro;
  final TalaoLido talao;
  final Loja loja;
  final EstadoTalao estado;
  final List<LinhaAnalisada> linhas;
}

class NaoReconhecido {
  const NaoReconhecido(this.ficheiro, this.motivo);
  final String ficheiro;
  final String motivo;
}

/// Escolha feita na pré-visualização para um texto de uma loja.
sealed class EscolhaArtigo {
  const EscolhaArtigo();
}

/// Ligar o texto a um artigo que já existe.
class LigarArtigo extends EscolhaArtigo {
  const LigarArtigo(this.artigoId);
  final String artigoId;
}

/// Criar um artigo novo com outro nome e/ou categoria.
class NovoArtigo extends EscolhaArtigo {
  const NovoArtigo({required this.nome, this.categoriaId});
  final String nome;
  final String? categoriaId;
}

/// Chave das escolhas: o mesmo texto na mesma loja liga-se junto.
String chaveEscolha(String lojaId, String texto) =>
    '$lojaId|${normalizar(texto).trim()}';

/// "PAO FORMA 14 CEREAIS" → "Pao forma 14 cereais".
String nomeDoTexto(String texto) {
  final t = texto.trim().toLowerCase();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Reparte [desconto] por [valores] em proporção, com a soma exata: os
/// cêntimos que sobram vão para os maiores valores; nenhum fica com mais
/// desconto do que o seu valor.
List<int> repartirDesconto(List<int> valores, int desconto) {
  final soma = valores.fold(0, (a, b) => a + b);
  if (valores.isEmpty || desconto <= 0 || soma <= 0) {
    return List.filled(valores.length, 0);
  }
  if (desconto >= soma) return [...valores];
  final partes = [for (final v in valores) desconto * v ~/ soma];
  var resto = desconto - partes.fold(0, (a, b) => a + b);
  final ordem = List.generate(valores.length, (i) => i)
    ..sort((a, b) => valores[b].compareTo(valores[a]));
  for (var k = 0; resto > 0; k = (k + 1) % ordem.length) {
    final i = ordem[k];
    if (partes[i] < valores[i]) {
      partes[i]++;
      resto--;
    }
  }
  return partes;
}

/// Lê os talões, reconhece a loja e marca os repetidos.
({List<TalaoAnalisado> taloes, List<NaoReconhecido> naoReconhecidos})
analisarTaloes(
  List<({String ficheiro, String texto})> lidos,
  Catalogo cat,
  List<CompraExistente> existentes,
) {
  final taloes = <TalaoAnalisado>[];
  final falhas = <NaoReconhecido>[];
  final vistos = <String>{};

  for (final (:ficheiro, :texto) in lidos) {
    final TalaoLido? t;
    try {
      t = lerTalao(texto);
    } on FormatException catch (e) {
      falhas.add(NaoReconhecido(ficheiro, e.message));
      continue;
    }
    if (t == null) {
      falhas.add(NaoReconhecido(ficheiro, 'Formato de talão não reconhecido'));
      continue;
    }
    final loja = cat.loja(t.loja);
    if (loja == null) {
      falhas.add(
        NaoReconhecido(
          ficheiro,
          'A loja ${t.loja} não existe; cria-a em Artigos',
        ),
      );
      continue;
    }

    final chave =
        '${loja.id}|${t.numero ?? '${dataIso(t.data)}|${t.totalCent}'}';
    final jaExiste = existentes.any(
      (e) =>
          e.lojaId == loja.id &&
          dataIso(e.data) == dataIso(t!.data) &&
          e.totalCent == t.totalCent,
    );
    final estado = jaExiste
        ? EstadoTalao.jaExiste
        : !vistos.add(chave)
        ? EstadoTalao.repetidoNoLote
        : t.bate && t.naoReconhecidas.isEmpty
        ? EstadoTalao.novo
        : EstadoTalao.aRever;

    final parte = repartirDesconto([
      for (final l in t.linhas) l.brutoCent - l.descontoCent,
    ], t.descontoCompraCent);
    taloes.add(
      TalaoAnalisado(
        ficheiro: ficheiro,
        talao: t,
        loja: loja,
        estado: estado,
        linhas: [
          for (final (i, l) in t.linhas.indexed)
            LinhaAnalisada(
              linha: l,
              descontoTotalCent: l.descontoCent + parte[i],
              artigo: cat.artigo(l.texto) ?? cat.artigo(nomeDoTexto(l.texto)),
              nomeNovo: nomeDoTexto(l.texto),
              categoriaSugerida: switch (categoriaDaSeccao(l.seccao)) {
                final nome? => cat.categoria(nome)?.id,
                null => null,
              },
            ),
        ],
      ),
    );
  }
  return (taloes: taloes, naoReconhecidos: falhas);
}

/// Texto de talão a guardar como alias depois de importar.
typedef AliasNovo = ({String lojaId, String texto, String artigoId});

/// O lote para a RPC importar_lote com os talões que entram
/// ([EstadoTalao.importa]); [escolhas] (por [chaveEscolha]) trocam o artigo
/// de uma linha. [aliases]: os textos que não ligavam a nenhum artigo
/// (novos ou ligados à mão), para gravar depois de importar — da próxima
/// vez ligam sozinhos, mesmo que o artigo mude de nome.
({LoteImportacao lote, List<AliasNovo> aliases}) loteDosTaloes(
  List<TalaoAnalisado> taloes,
  Map<String, EscolhaArtigo> escolhas,
  Catalogo cat, {
  String Function()? novoId,
}) {
  final lote = LoteImportacao();
  final r = Resolvedor(cat, lote, novoId: novoId);
  final nomeCategoria = {for (final c in cat.categorias) c.id: c.nome};
  final aliases = <String, AliasNovo>{};

  String artigoDe(TalaoAnalisado t, LinhaAnalisada l) {
    final unidade = l.linha.pesoG != null ? Unidade.kg : Unidade.un;
    switch (escolhas[chaveEscolha(t.loja.id, l.linha.texto)]) {
      case LigarArtigo(:final artigoId):
        return artigoId;
      case NovoArtigo(:final nome, :final categoriaId):
        return (r.artigoExistente(nome) ??
                r.criarArtigo(
                  nome,
                  categoria: nomeCategoria[categoriaId],
                  unidade: unidade,
                ))
            .id;
      case null:
        return (l.artigo ??
                r.artigoExistente(l.nomeNovo) ??
                r.criarArtigo(
                  l.nomeNovo,
                  categoria: nomeCategoria[l.categoriaSugerida],
                  unidade: unidade,
                ))
            .id;
    }
  }

  for (final t in taloes.where((t) => t.estado.importa)) {
    final compraId = r.novoId();
    final data = dataIso(t.talao.data);
    lote.compras.add({
      'id': compraId,
      'loja_id': t.loja.id,
      'local': t.talao.local,
      'data': data,
      'total_cent': t.talao.totalCent,
      'poupanca_cent': t.linhas.fold(0, (s, l) => s + l.descontoTotalCent),
      'ficheiro': t.ficheiro,
      'rever': t.estado == EstadoTalao.aRever,
    });
    for (final l in t.linhas) {
      final artigoId = artigoDe(t, l);
      final chave = chaveEscolha(t.loja.id, l.linha.texto);
      if (l.artigo == null || escolhas.containsKey(chave)) {
        aliases[chave] = (
          lojaId: t.loja.id,
          texto: l.linha.texto,
          artigoId: artigoId,
        );
      }
      lote.linhas.add({
        'id': r.novoId(),
        'compra_id': compraId,
        'artigo_id': artigoId,
        'texto_original': l.linha.texto,
        'quantidade': l.linha.quantidade,
        'peso_g': l.linha.pesoG,
        'preco_unit_cent': l.linha.precoUnitCent,
        'bruto_cent': l.linha.brutoCent,
        'desconto_cent': l.descontoTotalCent,
        'pago_cent': l.pagoCent,
      });
      lote.precos.add({
        'id': r.novoId(),
        'artigo_id': artigoId,
        'loja_id': t.loja.id,
        'data': data,
        'preco_cent': l.linha.precoUnitCent,
        'origem': 'talao',
      });
    }
  }
  return (lote: lote, aliases: aliases.values.toList());
}
