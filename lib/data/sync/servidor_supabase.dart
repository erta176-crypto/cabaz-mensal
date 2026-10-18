import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'servidor.dart';

class ServidorSupabase implements ServidorSync {
  ServidorSupabase(this._c);
  final SupabaseClient _c;

  static const _pagina = 1000;

  /// Sem resposta neste tempo, o pedido conta como falha de rede.
  static const _limite = Duration(seconds: 20);

  Future<T> _executar<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(_limite);
    } catch (e) {
      final erro = classificarErro(e);
      if (erro.transitorio && _jwtExpirado(e)) {
        try {
          await _c.auth.refreshSession();
        } catch (_) {
          // Sem rede: tenta outra vez mais tarde.
        }
      }
      throw erro;
    }
  }

  @override
  Future<void> inserir(
    String tabela,
    Map<String, dynamic> linha, {
    required String onConflict,
  }) => _executar(() => _c.from(tabela).upsert(linha, onConflict: onConflict));

  @override
  Future<void> atualizar(
    String tabela,
    Map<String, Object?> filtro,
    Map<String, dynamic> campos,
  ) => _executar(() async {
    var q = _c.from(tabela).update(campos);
    for (final MapEntry(:key, :value) in filtro.entries) {
      q = q.eq(key, value!);
    }
    await q;
  });

  @override
  Future<void> rpc(String nome, Map<String, dynamic> params) =>
      _executar(() => _c.rpc(nome, params: params));

  @override
  Future<DateTime> agora() => _executar(
    () async => DateTime.parse(await _c.rpc('agora') as String),
  );

  @override
  Future<List<Map<String, dynamic>>> puxar(String tabela, DateTime? desde) =>
      _executar(() async {
        final desempate = tabela == 'preferencias' ? 'user_id' : 'id';
        final todas = <Map<String, dynamic>>[];
        var inicio = 0;
        while (true) {
          var q = _c.from(tabela).select();
          if (desde != null) {
            q = q.gt('atualizado_em', desde.toUtc().toIso8601String());
          }
          final pagina = await q
              .order('atualizado_em', ascending: true)
              .order(desempate, ascending: true)
              .range(inicio, inicio + _pagina - 1);
          todas.addAll(pagina);
          if (pagina.length < _pagina) return todas;
          inicio += _pagina;
        }
      });

  @override
  Stream<void> alteracoes(List<String> tabelas) {
    late final StreamController<void> controlador;
    RealtimeChannel? canal;
    controlador = StreamController<void>(
      onListen: () {
        var c = _c.channel('sync-${const Uuid().v4()}');
        for (final t in tabelas) {
          c = c.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: t,
            callback: (_) => controlador.add(null),
          );
        }
        canal = c.subscribe();
      },
      onCancel: () async {
        final c = canal;
        if (c != null) await _c.removeChannel(c);
      },
    );
    return controlador.stream;
  }

  bool _jwtExpirado(Object e) =>
      e is PostgrestException &&
      (e.code == 'PGRST301' || e.message.toLowerCase().contains('jwt'));
}

/// Decide se um erro é transitório (tentar mais tarde) ou permanente.
/// Sem importar dart:io, para compilar também na web.
ErroSync classificarErro(Object e) {
  if (e is ErroSync) return e;
  if (e is PostgrestException) {
    final codigo = e.code ?? '';
    final transitorio =
        codigo.isEmpty ||
        codigo.startsWith('PGRST3') || // JWT
        codigo.startsWith('08') || // ligação
        codigo.startsWith('53') || // recursos
        codigo.startsWith('57') || // timeout, servidor a reiniciar
        codigo.startsWith('40') || // serialização, deadlock
        RegExp(r'^5\d\d$').hasMatch(codigo) ||
        e.message.toLowerCase().contains('jwt');
    final motivo = switch (codigo) {
      '42501' => 'Sem permissão (RLS)',
      '23505' => 'Registo repetido',
      '23503' => 'Referência a um registo que não existe',
      _ => 'Erro do servidor',
    };
    return ErroSync(
      '$motivo: ${e.message}',
      transitorio: transitorio,
    );
  }
  if (e is AuthException) {
    return ErroSync(
      'Sessão: ${e.message}',
      transitorio: e is AuthRetryableFetchException,
    );
  }
  // Falhas de rede (SocketException, ClientException, fetch na web…).
  return ErroSync('Sem ligação ao servidor ($e)', transitorio: true);
}
