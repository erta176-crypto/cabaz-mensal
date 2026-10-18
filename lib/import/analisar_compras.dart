/// Importar "Compras e linhas": uma linha do ficheiro por linha de talão,
/// agrupadas em compras.
library;

import '../domain/dinheiro.dart';
import '../domain/modelos.dart';
import 'analise_comum.dart';
import 'campos.dart';
import 'previsualizacao.dart';
import 'tabela_lida.dart';
import 'valores.dart';

const avisoTaloesJuntos = 'Possíveis talões juntos';

class _Linha {
  _Linha(this.numero, this.valores);
  final int numero;
  final List<String> valores;
  late Loja loja;
  late DateTime data;
  String? local;
  late String nome;
  String? texto;
  int? quantidade;
  int? pesoG;
  late int precoUnit;
  late int bruto;
  late int desconto;
  late int pago;
  int? total;
  late String grupo;
}

Previsualizacao analisarCompras(
  TabelaLida tabela,
  List<Campo> campos,
  Catalogo cat,
  List<CompraExistente> existentes, {
  String Function()? novoId,
}) {
  final col = Colunas(campos);
  final lote = LoteImportacao();
  final r = Resolvedor(cat, lote, novoId: novoId);
  final previas = <int, LinhaPrevia>{};
  final validas = <_Linha>[];

  for (final (i, l) in tabela.linhas.indexed) {
    String? erro;
    final x = _Linha(i + 1, l);
    int? dinheiro(Campo c) {
      final t = col.valor(l, c);
      if (t.isEmpty) return null;
      final v = centDeTexto(t);
      if (v == null) erro ??= 'Valor inválido em ${c.rotulo}: $t';
      return v;
    }

    final lojaTxt = col.valor(l, Campo.loja);
    final loja = lojaTxt.isEmpty ? null : cat.loja(lojaTxt);
    final data = lerData(col.valor(l, Campo.data));
    x.nome = col.valor(l, Campo.artigo);
    x.texto = col.valor(l, Campo.textoTalao).isEmpty
        ? null
        : col.valor(l, Campo.textoTalao);
    final qtdTxt = col.valor(l, Campo.quantidade);
    final qtd = lerNumero(qtdTxt);
    final pesoTxt = col.valor(l, Campo.peso);
    x.pesoG = lerPesoG(pesoTxt);
    final precoUnit = dinheiro(Campo.precoUnit);
    final bruto = dinheiro(Campo.bruto);
    x.desconto = dinheiro(Campo.desconto) ?? 0;
    final pago = dinheiro(Campo.pago);
    x.total = dinheiro(Campo.totalCompra);

    if (lojaTxt.isEmpty) {
      erro ??= 'Falta a loja';
    } else if (loja == null) {
      erro ??= 'Loja desconhecida: $lojaTxt';
    }
    if (data == null) erro ??= 'Data inválida: ${col.valor(l, Campo.data)}';
    if (x.nome.isEmpty && x.texto == null) erro ??= 'Artigo vazio';
    if (qtdTxt.isNotEmpty && (qtd == null || qtd <= 0 || qtd != qtd.round())) {
      erro ??= 'Quantidade inválida: $qtdTxt';
    }
    if (pesoTxt.isNotEmpty && x.pesoG == null) {
      erro ??= 'Peso inválido: $pesoTxt';
    }
    x.quantidade = x.pesoG == null ? (qtd?.toInt() ?? 1) : null;
    final calculado = precoUnit == null
        ? null
        : (x.pesoG != null
              ? (x.pesoG! * precoUnit / 1000).round()
              : x.quantidade! * precoUnit);
    final pagoFinal = pago ?? (bruto != null ? bruto - x.desconto : calculado);
    if (pagoFinal == null) erro ??= 'Falta o valor pago';

    if (erro != null) {
      previas[i] = LinhaPrevia(
        numero: i + 1,
        valores: l,
        estado: EstadoLinha.erro,
        motivo: erro,
      );
      continue;
    }
    x
      ..loja = loja!
      ..data = data!
      ..local = col.valor(l, Campo.local).isEmpty
          ? null
          : col.valor(l, Campo.local)
      ..pago = pagoFinal!
      ..bruto = bruto ?? pagoFinal + x.desconto;
    x.precoUnit =
        precoUnit ??
        precoUnitarioCent(
          brutoCent: x.bruto,
          quantidade: x.quantidade,
          pesoG: x.pesoG,
        )!;
    final compra = col.valor(l, Campo.compra);
    x.grupo = compra.isNotEmpty
        ? 'c:$compra'
        : '${loja.id}|${dataIso(data)}|${x.local ?? ''}|${x.total ?? ''}';
    validas.add(x);
  }

  // Agrupar em compras, pela ordem em que aparecem.
  final grupos = <String, List<_Linha>>{};
  for (final x in validas) {
    (grupos[x.grupo] ??= []).add(x);
  }
  final semChaveForte = !col.tem(Campo.compra) && !col.tem(Campo.totalCompra);

  for (final linhas in grupos.values) {
    final p = linhas.first;
    final soma = linhas.fold(0, (s, x) => s + x.pago);
    final total = linhas.map((x) => x.total).nonNulls.firstOrNull ?? soma;
    bool mesmoDia(CompraExistente e) =>
        e.lojaId == p.loja.id && dataIso(e.data) == dataIso(p.data);
    final existe = existentes.any((e) => mesmoDia(e) && e.totalCent == total);
    final mesmosLocal = existentes
        .where((e) => mesmoDia(e) && (e.local ?? '') == (p.local ?? ''))
        .length;
    final aviso = semChaveForte && mesmosLocal >= 2 ? avisoTaloesJuntos : null;

    if (!existe) {
      final compraId = r.novoId();
      lote.compras.add({
        'id': compraId,
        'loja_id': p.loja.id,
        'local': p.local,
        'data': dataIso(p.data),
        'total_cent': total,
        'poupanca_cent': linhas.fold(0, (s, x) => s + x.desconto),
        'rever': soma != total,
      });
      for (final x in linhas) {
        final nome = x.nome.isNotEmpty ? x.nome : x.texto!;
        final artigo =
            r.artigoExistente(nome) ??
            (x.texto == null ? null : r.artigoExistente(x.texto!)) ??
            r.criarArtigo(
              nome,
              unidade: x.pesoG != null ? Unidade.kg : Unidade.un,
            );
        lote.linhas.add({
          'id': r.novoId(),
          'compra_id': compraId,
          'artigo_id': artigo.id,
          'texto_original': x.texto ?? x.nome,
          'quantidade': x.quantidade,
          'peso_g': x.pesoG,
          'preco_unit_cent': x.precoUnit,
          'bruto_cent': x.bruto,
          'desconto_cent': x.desconto,
          'pago_cent': x.pago,
        });
        lote.precos.add({
          'id': r.novoId(),
          'artigo_id': artigo.id,
          'loja_id': p.loja.id,
          'data': dataIso(p.data),
          'preco_cent': x.precoUnit,
          'origem': 'talao',
        });
      }
    }
    for (final x in linhas) {
      previas[x.numero - 1] = LinhaPrevia(
        numero: x.numero,
        valores: x.valores,
        estado: existe ? EstadoLinha.jaExiste : EstadoLinha.novo,
        aviso: aviso,
      );
    }
  }
  return Previsualizacao(
    linhas: [for (var i = 0; i < tabela.linhas.length; i++) previas[i]!],
    lote: lote,
  );
}
