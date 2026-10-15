/// Minúsculas e sem acentos, para pesquisar ("Maçã" encontra "maca").
String normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : para[i]);
  }
  return b.toString();
}

/// True se todas as palavras de [termo] aparecem em algum dos [textos].
bool correspondeA(String termo, Iterable<String> textos) {
  final palavras = normalizar(
    termo,
  ).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (palavras.isEmpty) return true;
  final alvo = textos.map(normalizar).join(' ');
  return palavras.every(alvo.contains);
}
