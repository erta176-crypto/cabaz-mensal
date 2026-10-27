/// Leitor dos talões do Lidl (texto do pdfrx). Regras em
/// docs/planning/fase-5.md, secção 0.3.
library;

import 'talao.dart';

final _inline = RegExp(r'^(.+?) (\d+,\d{2}) x (\d+) (\d+,\d{2}) [A-Z]$');
final _artigo = RegExp(r'^(.+?) (\d+,\d{2}) [A-Z]$');
final _soValor = RegExp(r'^(\d+,\d{2}) [A-Z]$');
final _quantidade = RegExp(r'^(\d+) x (\d+,\d{2})$');
final _peso = RegExp(r'^(\d+,\d{3}) kg x (\d+,\d{2}) EUR/kg$');
final _desconto = RegExp(r'^(.+?) -(\d+,\d{2})$');
final _separador = RegExp(r'^[-=]+$');
final _temValor = RegExp(r'\d+,\d{2}');
final _total = RegExp(r'^Total (\d+,\d{2})$');
final _data = RegExp(r'Data de Venda: (\d{4})-(\d{2})-(\d{2})');
final _numero = RegExp(r'^No : (FS \S+)');

/// "VILA FICTICIA" → "Vila Ficticia".
String capitalizar(String s) => s
    .toLowerCase()
    .split(' ')
    .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
    .join(' ');

/// A linha com a quantidade ou o peso que veio na linha seguinte.
LinhaTalao _com(
  LinhaTalao a, {
  int? quantidade,
  int? pesoG,
  required int preco,
}) => LinhaTalao(
  texto: a.texto,
  quantidade: quantidade,
  pesoG: pesoG,
  precoUnitCent: preco,
  brutoCent: a.brutoCent,
  descontoCent: a.descontoCent,
);

/// null se o texto não é de um talão do Lidl. Lança [FormatException] se
/// é, mas falta a data ou o total.
TalaoLido? lerLidl(String texto) {
  if (!texto.contains('LIDL & Cia')) return null;
  final ls = linhasDe(texto);
  final dataM = ls.map(_data.firstMatch).nonNulls.firstOrNull;
  if (dataM == null) throw const FormatException('Talão sem data');

  final linhas = <LinhaTalao>[];
  final estranhas = <String>[];
  int? total;
  // Forma em 3 linhas: o texto, depois a quantidade ou o peso, depois o
  // valor. [pendente] é o texto; [meia] já tem a quantidade ou o peso.
  String? pendente;
  LinhaTalao? meia;

  void largarPendente() {
    if (pendente != null) estranhas.add(pendente!);
    pendente = null;
    meia = null;
  }

  for (final l in ls.skip(ls.indexOf('EUR') + 1)) {
    if (_total.firstMatch(l) case final m?) {
      total = centTalao(m[1]!);
      break;
    }
    if (_separador.hasMatch(l)) continue;

    final q = _quantidade.firstMatch(l);
    final p = _peso.firstMatch(l);
    if (pendente != null && meia == null && (q != null || p != null)) {
      final base = LinhaTalao(texto: pendente!, precoUnitCent: 0, brutoCent: 0);
      meia = q != null
          ? _com(base, quantidade: int.parse(q[1]!), preco: centTalao(q[2]!))
          : _com(base, pesoG: gramasTalao(p![1]!), preco: centTalao(p[2]!));
      continue;
    }
    if (_soValor.firstMatch(l) case final m? when meia != null) {
      final b = meia!;
      linhas.add(
        LinhaTalao(
          texto: b.texto,
          quantidade: b.quantidade,
          pesoG: b.pesoG,
          precoUnitCent: b.precoUnitCent,
          brutoCent: centTalao(m[1]!),
        ),
      );
      pendente = null;
      meia = null;
      continue;
    }
    largarPendente();

    if (_inline.firstMatch(l) case final m?) {
      linhas.add(
        LinhaTalao(
          texto: m[1]!,
          quantidade: int.parse(m[3]!),
          precoUnitCent: centTalao(m[2]!),
          brutoCent: centTalao(m[4]!),
        ),
      );
    } else if (_artigo.firstMatch(l) case final m?) {
      final valor = centTalao(m[2]!);
      linhas.add(
        LinhaTalao(
          texto: m[1]!,
          quantidade: 1,
          precoUnitCent: valor,
          brutoCent: valor,
        ),
      );
    } else if (q != null && linhas.isNotEmpty) {
      linhas.add(
        _com(
          linhas.removeLast(),
          quantidade: int.parse(q[1]!),
          preco: centTalao(q[2]!),
        ),
      );
    } else if (p != null && linhas.isNotEmpty) {
      linhas.add(
        _com(
          linhas.removeLast(),
          pesoG: gramasTalao(p[1]!),
          preco: centTalao(p[2]!),
        ),
      );
    } else if (_desconto.firstMatch(l) case final m? when linhas.isNotEmpty) {
      linhas.add(linhas.removeLast().comDesconto(centTalao(m[2]!)));
    } else if (!_temValor.hasMatch(l)) {
      pendente = l;
    } else {
      estranhas.add(l);
    }
  }
  largarPendente();
  if (total == null) throw const FormatException('Talão sem total');

  final primeira = ls.first;
  final traco = primeira.indexOf(' - ');
  return TalaoLido(
    loja: 'Lidl',
    local: traco < 0
        ? null
        : 'Lidl ${capitalizar(primeira.substring(traco + 3))}',
    data: DateTime(
      int.parse(dataM[1]!),
      int.parse(dataM[2]!),
      int.parse(dataM[3]!),
    ),
    numero: ls.map(_numero.firstMatch).nonNulls.firstOrNull?[1],
    linhas: linhas,
    totalCent: total,
    naoReconhecidas: estranhas,
  );
}
