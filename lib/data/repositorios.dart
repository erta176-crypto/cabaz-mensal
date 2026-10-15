/// Contratos da camada de dados. A interface só conhece estes tipos.
///
/// Leituras são Streams (`observar…`) para que, na Fase 1, uma cache local
/// (drift) possa emitir primeiro os dados locais e depois os do servidor, e
/// as escritas possam ir para uma fila de alterações sem mudar os ecrãs.
library;

import '../domain/modelos.dart';

abstract interface class AuthRepository {
  bool get temSessao;
  String? get email;

  /// Emite sempre que a sessão muda (entrar, sair, renovar).
  Stream<bool> observarSessao();

  Future<void> entrar({required String email, required String palavraPasse});

  /// Devolve true se a conta ficou com sessão aberta; false se o Supabase
  /// exigir confirmação por email antes de entrar.
  Future<bool> criarConta({
    required String email,
    required String palavraPasse,
  });

  Future<void> sair();
}

abstract interface class LojasRepository {
  Stream<List<Loja>> observarLojas();
  Future<List<ResumoLoja>> resumoPorLoja();
}

abstract interface class CategoriasRepository {
  Stream<List<Categoria>> observarCategorias();
  Future<void> criar({required String nome, required int ordem});
  Future<void> atualizar(Categoria categoria);

  /// Elimina a categoria. Os artigos que tinha passam para [moverPara]
  /// (ou ficam sem categoria, se for null).
  Future<void> eliminar(String id, {String? moverPara});
}

abstract interface class ArtigosRepository {
  Stream<List<Artigo>> observarArtigos();
  Stream<List<PrecoAtual>> observarPrecosAtuais();

  /// Cria ou atualiza o artigo. [precosCent] tem o preço por loja (id da loja);
  /// só os preços que mudaram geram um novo registo de preço 'manual'.
  Future<void> guardar(
    Artigo artigo, {
    Map<String, int?> precosCent = const {},
    bool novo = false,
  });

  Future<void> eliminar(String id);
}

abstract interface class ComprasRepository {
  Future<int> contarCompras();
}

/// Resultado devolvido pela RPC importar_seed.
class ContagensImportacao {
  const ContagensImportacao(this.valores);
  final Map<String, int> valores;

  int operator [](String chave) => valores[chave] ?? 0;
}

abstract interface class DadosRepository {
  /// True se o utilizador já tem lojas, artigos ou compras.
  Future<bool> temDados();

  /// Importa tudo numa só transação no servidor (RPC importar_seed).
  Future<ContagensImportacao> importar(
    Map<String, dynamic> payload, {
    required bool substituir,
  });

  /// Lê todas as tabelas do utilizador, em bruto (mapas por tabela).
  Future<Map<String, List<Map<String, dynamic>>>> lerTudo();

  Future<void> apagarTudo();
}

/// Erro de dados com mensagem pronta a mostrar ao utilizador.
class ErroDados implements Exception {
  const ErroDados(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}
