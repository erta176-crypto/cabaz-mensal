/// Lista em texto para o WhatsApp (e base do PDF da lista): título, um bloco
/// por categoria com emoji, e "• Artigo — 2 kg (Lidl)". Sem os comprados.
library;

import '../domain/modelos.dart';
import '../domain/texto.dart';

class LinhaParaTexto {
  const LinhaParaTexto({
    required this.loja,
    required this.categoria,
    required this.artigo,
    required this.quantidade,
  });

  final String loja;

  /// Null = sem categoria.
  final Categoria? categoria;
  final String artigo;

  /// Já formatada ("2 kg", "1,3 kg").
  final String quantidade;
}

class BlocoLista {
  const BlocoLista(this.titulo, this.linhas);
  final String titulo;
  final List<String> linhas;
}

/// Palavras-chave (no nome normalizado da categoria) → emoji. A ordem conta:
/// "mercearia vegetariana" → 🌱, "carne e charcutaria" → 🍗.
const _emojis = [
  (['vegetarian', 'vegan'], '🌱'),
  (['lactic', 'leite', 'ovos', 'queijo', 'iogurt'], '🥛'),
  (['fruta'], '🍎'),
  (['legum', 'verdura', 'horta'], '🥕'),
  (['carne', 'talho', 'aves', 'frango'], '🍗'),
  (['charcut', 'enchido'], '🥓'),
  (['peixe', 'marisco', 'pescado'], '🐟'),
  (['padaria', 'pao'], '🥖'),
  (['pastelaria', 'bolo'], '🥐'),
  (['mercearia'], '🥫'),
  (['congelad', 'gelad'], '🧊'),
  (['doce', 'snack', 'chocolate', 'bolacha'], '🍫'),
  (['bebida', 'agua', 'sumo', 'vinho', 'cerveja', 'infus'], '🧃'),
  (['limpeza', 'detergente'], '🧽'),
  (['casa'], '🏠'),
  (['higiene', 'beleza', 'cosmet'], '🧴'),
  (['saude', 'suplement', 'farmac'], '💊'),
  (['bebe'], '🍼'),
  (['animai', 'animal', 'mascote'], '🐾'),
  (['outro'], '📦'),
];

String emojiCategoria(String nome) {
  final n = normalizar(nome);
  for (final (chaves, emoji) in _emojis) {
    if (chaves.any(n.contains)) return emoji;
  }
  return '🛍️';
}

/// Blocos por categoria (pela ordem das categorias, "Sem categoria" no
/// fim). [mostrarLoja] acrescenta " (Loja)" a cada linha.
List<BlocoLista> blocosLista(
  List<LinhaParaTexto> linhas, {
  required bool mostrarLoja,
}) {
  final porCategoria = <String, List<LinhaParaTexto>>{};
  final categoria = <String, Categoria?>{};
  for (final l in linhas) {
    final k = l.categoria?.id ?? '';
    (porCategoria[k] ??= []).add(l);
    categoria[k] = l.categoria;
  }
  final chaves = porCategoria.keys.toList()
    ..sort((a, b) {
      if (a == '') return 1;
      if (b == '') return -1;
      return categoria[a]!.ordem.compareTo(categoria[b]!.ordem);
    });
  return [
    for (final k in chaves)
      BlocoLista(
        k == ''
            ? '🛍️ Sem categoria'
            : '${emojiCategoria(categoria[k]!.nome)} ${categoria[k]!.nome}',
        [
          for (final l
              in porCategoria[k]!..sort(
                (a, b) =>
                    a.artigo.toLowerCase().compareTo(b.artigo.toLowerCase()),
              ))
            '• ${l.artigo} — ${l.quantidade}${mostrarLoja ? ' (${l.loja})' : ''}',
        ],
      ),
  ];
}

String tituloLista({String? loja, required DateTime data}) =>
    '🛒 Lista de compras · ${loja ?? 'Todas as lojas'} · '
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';

/// [loja] null = "Todas as lojas" (e cada linha mostra a loja).
String textoLista(
  List<LinhaParaTexto> linhas, {
  String? loja,
  required DateTime data,
}) {
  final b = StringBuffer(tituloLista(loja: loja, data: data));
  for (final bloco in blocosLista(linhas, mostrarLoja: loja == null)) {
    b
      ..writeln()
      ..writeln()
      ..write(bloco.titulo);
    for (final l in bloco.linhas) {
      b
        ..writeln()
        ..write(l);
    }
  }
  return b.toString();
}
