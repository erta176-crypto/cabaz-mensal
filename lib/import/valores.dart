/// Conversão do texto das células para valores da app. Dinheiro sempre em
/// cêntimos inteiros, via `centDeTexto` (que usa (v * 100).round()).
library;

import '../domain/dinheiro.dart';

export '../domain/dinheiro.dart' show centDeTexto;

/// Datas dd/mm/aaaa ou aaaa-mm-dd. Devolve null se for inválida
/// (ex.: 31/02/2026).
DateTime? lerData(String texto) {
  final t = texto.trim();
  final pt = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(t);
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  final (int a, int m, int d) = switch ((pt, iso)) {
    (final p?, _) => (int.parse(p[3]!), int.parse(p[2]!), int.parse(p[1]!)),
    (_, final i?) => (int.parse(i[1]!), int.parse(i[2]!), int.parse(i[3]!)),
    _ => (0, 0, 0),
  };
  if (a == 0) return null;
  final data = DateTime(a, m, d);
  return data.year == a && data.month == m && data.day == d ? data : null;
}

/// Número decimal com vírgula ou ponto ("1,5", "1.5", "2").
num? lerNumero(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = num.tryParse(t);
  return v == null || v.isNaN || v.isInfinite ? null : v;
}

/// Quantidade em texto livre: "2" → (2, null); "1,5 kg" → (1.5, 'kg');
/// "2 pacotes" → (2, 'pacotes'); "q.b." → (null, 'q.b.').
({num? valor, String? unidade}) lerQuantidadeTexto(String texto) {
  final t = texto.trim();
  final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(t);
  if (m == null) return (valor: null, unidade: t.isEmpty ? null : t);
  final resto = m[2]!.trim().toLowerCase();
  return (valor: lerNumero(m[1]!), unidade: resto.isEmpty ? null : resto);
}

/// "Sim", "S", "x", "true", "1" → true.
bool lerSimNao(String texto) => const {
  'sim',
  's',
  'x',
  'true',
  'verdadeiro',
  '1',
  'yes',
  'y',
}.contains(texto.trim().toLowerCase());

/// Kg em texto ("0,794") → gramas inteiras.
int? lerPesoG(String texto) {
  final v = lerNumero(texto);
  return v == null || v <= 0 ? null : kgParaG(v);
}
