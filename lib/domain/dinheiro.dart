/// Regras de dinheiro e pesos.
///
/// Dinheiro é SEMPRE guardado em cêntimos inteiros e pesos em gramas inteiros.
/// Os doubles só existem à entrada (ficheiros, campos de texto) e são
/// convertidos de imediato; nunca se somam doubles.
library;

/// Converte euros (ex.: 4652.26) em cêntimos (465226).
int eurosParaCent(num euros) => (euros * 100).round();

/// Converte quilos (ex.: 0.794) em gramas (794).
int kgParaG(num kg) => (kg * 1000).round();

/// Converte gramas em quilos, só para apresentação ou exportação.
double gParaKg(int gramas) => gramas / 1000;

/// Lê um valor em euros escrito pelo utilizador ("1,23", "1.23", "1 234,50 €").
/// Devolve null se o texto estiver vazio ou não for um número válido.
int? centDeTexto(String texto) {
  var t = texto.replaceAll('€', '').replaceAll(RegExp(r'\s'), '').trim();
  if (t.isEmpty) return null;
  final temVirgula = t.contains(',');
  final temPonto = t.contains('.');
  if (temVirgula && temPonto) {
    // O último separador é o decimal; o outro é de milhares.
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (temVirgula) {
    t = t.replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  return eurosParaCent(v);
}

/// Preço unitário em cêntimos: por unidade (artigos 'un') ou por quilo
/// (artigos ao peso). Devolve null se não houver quantidade nem peso.
int? precoUnitarioCent({
  required int brutoCent,
  int? quantidade,
  int? pesoG,
}) {
  if (pesoG != null && pesoG > 0) return (brutoCent * 1000 / pesoG).round();
  if (quantidade != null && quantidade > 0) {
    return (brutoCent / quantidade).round();
  }
  return null;
}
