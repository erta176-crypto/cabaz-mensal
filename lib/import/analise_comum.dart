/// Peças partilhadas pelas três análises (artigos, compras, lista).
library;

import 'package:uuid/uuid.dart';

import '../domain/modelos.dart';
import '../domain/texto.dart';
import 'campos.dart';
import 'previsualizacao.dart';

/// Lê uma célula pelo campo a que a coluna foi ligada ('' se não houver).
class Colunas {
  Colunas(this.campos);
  final List<Campo> campos;

  bool tem(Campo c) => campos.contains(c);

  String valor(List<String> linha, Campo c) {
    final i = campos.indexOf(c);
    return i < 0 || i >= linha.length ? '' : linha[i].trim();
  }
}

/// "kg", "quilos" → kg; "un", "unidades" → un; outro texto → null.
Unidade? unidadeDeTexto(String texto) {
  final t = normalizar(texto).trim().replaceAll('.', '');
  if (const {'kg', 'kgs', 'quilo', 'quilos', 'kilo', 'kilos'}.contains(t)) {
    return Unidade.kg;
  }
  if (const {'un', 'unidade', 'unidades', 'u', 'uni', 'unid'}.contains(t)) {
    return Unidade.un;
  }
  return null;
}

/// Encontra ou cria artigos e categorias, pondo no [lote] o que for novo.
/// Um artigo ou categoria apagado com o mesmo nome é reativado com o mesmo
/// id (a RPC faz upsert pelo id com apagado_em = null).
class Resolvedor {
  Resolvedor(this.cat, this.lote, {String Function()? novoId})
    : _novoId = novoId ?? const Uuid().v4,
      _ordem = cat.proximaOrdem;

  final Catalogo cat;
  final LoteImportacao lote;
  final String Function() _novoId;
  int _ordem;

  final _artigosNovos = <String, Artigo>{};
  final _categoriasNovas = <String, String>{};

  String novoId() => _novoId();

  /// Id de uma categoria ativa com este nome, sem criar nada.
  String? categoriaExistente(String nome) =>
      cat.categoria(nome)?.id ?? _categoriasNovas[normalizar(nome).trim()];

  /// Id da categoria, criando-a (ou reativando-a) no lote se preciso.
  String? garantirCategoria(String nome) {
    if (nome.trim().isEmpty) return null;
    final existente = categoriaExistente(nome);
    if (existente != null) return existente;
    final apagada = cat.categoriaApagada(nome);
    final id = apagada?.id ?? _novoId();
    lote.categorias[id] = {
      'id': id,
      'nome': apagada?.nome ?? nome.trim(),
      'ordem': apagada?.ordem ?? _ordem++,
    };
    _categoriasNovas[normalizar(nome).trim()] = id;
    return id;
  }

  /// Artigo ativo (pelo nome ou alias) ou já criado neste ficheiro.
  Artigo? artigoExistente(String nome) =>
      cat.artigo(nome) ?? _artigosNovos[normalizar(nome).trim()];

  /// Artigo novo neste ficheiro? (para contar Novo em vez de Já existe)
  bool criadoAqui(String id) => _artigosNovos.values.any((a) => a.id == id);

  /// Cria (ou reativa) o artigo no lote.
  Artigo criarArtigo(String nome, {String? categoria, Unidade? unidade}) {
    final apagado = cat.artigoApagado(nome);
    final artigo = Artigo(
      id: apagado?.id ?? _novoId(),
      nome: apagado?.nome ?? nome.trim(),
      categoriaId: (categoria == null || categoria.trim().isEmpty)
          ? apagado?.categoriaId
          : garantirCategoria(categoria),
      unidade: unidade ?? apagado?.unidade ?? Unidade.un,
    );
    lote.artigos[artigo.id] = artigo.toMap();
    _artigosNovos[normalizar(nome).trim()] = artigo;
    return artigo;
  }
}
