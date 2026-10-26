import '../../domain/modelos.dart';
import '../../domain/texto.dart';

/// O que a pesquisa do Histórico envia ao servidor: os artigos cujo nome,
/// texto do talão (sem acentos) ou EAN contém o termo, e o texto escrito
/// para procurar no `texto_original` das linhas.
({List<String> artigoIds, String? texto}) termosPesquisa(
  String escrito,
  List<Artigo> artigos,
  Map<String, List<String>> aliases,
) {
  final texto = escrito.trim();
  if (texto.isEmpty) return (artigoIds: const [], texto: null);
  final t = normalizar(texto);
  final ids = <String>{
    for (final a in artigos)
      if (normalizar(a.nome).contains(t)) a.id,
    for (final MapEntry(key: id, value: textos) in aliases.entries)
      if (textos.any((x) => normalizar(x).contains(t))) id,
    for (final a in artigos)
      if (a.ean?.contains(texto) ?? false) a.id,
  };
  return (artigoIds: ids.toList(), texto: texto);
}
