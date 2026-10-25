/// Código de barras (EAN/GTIN) do artigo.
library;

/// Normaliza o código escrito ou lido pelo scan: tira os espaços, valida o
/// dígito de controlo GS1 e guarda o EAN-13 da embalagem quando é o mesmo
/// produto: o UPC-A (12 dígitos) ganha um 0 à frente e o GTIN-14 que começa
/// por 0 perde-o. Aceita EAN-8, EAN-13 e GTIN-14. Devolve null se o código não
/// for válido.
String? normalizarEan(String texto) {
  var t = texto.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[0-9]+$').hasMatch(t)) return null;
  if (t.length == 12) t = '0$t';
  if (t.length != 8 && t.length != 13 && t.length != 14) return null;
  var soma = 0;
  for (var i = t.length - 2, peso = 3; i >= 0; i--, peso = 4 - peso) {
    soma += int.parse(t[i]) * peso;
  }
  if ((10 - soma % 10) % 10 != int.parse(t[t.length - 1])) return null;
  return t.length == 14 && t.startsWith('0') ? t.substring(1) : t;
}
