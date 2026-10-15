import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositorios.dart';

/// O PostgREST devolve no máximo 1000 linhas por pedido; lemos por páginas.
const _tamanhoPagina = 1000;

Future<List<Map<String, dynamic>>> buscarTudo(
  SupabaseClient cliente,
  String tabela, {
  String colunas = '*',
  String ordem = 'id',
}) async {
  final todas = <Map<String, dynamic>>[];
  var inicio = 0;
  while (true) {
    final pagina = await cliente
        .from(tabela)
        .select(colunas)
        .order(ordem)
        .range(inicio, inicio + _tamanhoPagina - 1);
    todas.addAll(pagina);
    if (pagina.length < _tamanhoPagina) return todas;
    inicio += _tamanhoPagina;
  }
}

/// Converte erros do Supabase em mensagens em pt-PT.
Object traduzirErro(Object e) {
  if (e is ErroDados) return e;
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return const ErroDados('Email ou palavra-passe errados.');
    }
    if (m.contains('email not confirmed')) {
      return const ErroDados(
        'Ainda não confirmaste o email. Abre a mensagem que recebeste.',
      );
    }
    if (m.contains('signups not allowed') || m.contains('signup is disabled')) {
      return const ErroDados('A criação de contas novas está desligada.');
    }
    if (m.contains('already registered')) {
      return const ErroDados('Já existe uma conta com este email.');
    }
    if (m.contains('password')) {
      return const ErroDados(
        'Palavra-passe inválida (mínimo de 6 caracteres).',
      );
    }
    return ErroDados('Erro de autenticação: ${e.message}');
  }
  if (e is PostgrestException) {
    if (e.message.contains('JA_EXISTEM_DADOS')) {
      return const ErroDados('Já existem dados nesta conta.');
    }
    if (e.message.contains('SEM_SESSAO')) {
      return const ErroDados('A sessão terminou. Entra outra vez.');
    }
    if (e.code == '23505') {
      return const ErroDados('Já existe um registo com esse nome.');
    }
    if (e.code == '23503') {
      return const ErroDados(
        'Não é possível eliminar: há outros registos que dependem deste.',
      );
    }
    return ErroDados('Erro na base de dados: ${e.message}');
  }
  return e;
}

Future<T> comErrosTraduzidos<T>(Future<T> Function() f) async {
  try {
    return await f();
  } catch (e) {
    final t = traduzirErro(e);
    if (identical(t, e)) rethrow;
    throw t;
  }
}
