/// O que a sincronização precisa do servidor. A implementação real está em
/// servidor_supabase.dart; os testes usam uma versão em memória.
library;

abstract interface class ServidorSync {
  /// Upsert de uma linha completa (criar, ou reativar pela chave natural).
  Future<void> inserir(
    String tabela,
    Map<String, dynamic> linha, {
    required String onConflict,
  });

  /// UPDATE só das [campos] alterados, nas linhas que cumprem o [filtro].
  Future<void> atualizar(
    String tabela,
    Map<String, Object?> filtro,
    Map<String, dynamic> campos,
  );

  Future<void> rpc(String nome, Map<String, dynamic> params);

  /// Linhas (incluindo apagadas) com atualizado_em > [desde]; todas se null.
  Future<List<Map<String, dynamic>>> puxar(String tabela, DateTime? desde);

  /// Hora do servidor (para o cursor da receção não ficar parado).
  Future<DateTime> agora();

  /// Avisa (sem dados) quando alguma das tabelas muda no servidor.
  Stream<void> alteracoes(List<String> tabelas);
}

class ErroSync implements Exception {
  const ErroSync(this.mensagem, {required this.transitorio});

  final String mensagem;

  /// true: sem rede, timeout, servidor indisponível → tentar mais tarde.
  /// false: erro que se vai repetir (RLS, dados inválidos) → não bloquear a fila.
  final bool transitorio;

  @override
  String toString() => mensagem;
}
