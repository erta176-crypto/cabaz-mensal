import 'dart:convert';

import 'package:drift/drift.dart';

part 'base_local.g.dart';

/// Linhas das tabelas sincronizadas, guardadas com as colunas do servidor
/// em JSON. A chave é o id, ou a chave natural nas tabelas que a têm
/// (itens_lista, aliases, preferencias) — ver [chaveDe].
@DataClassName('RegistoLocal')
class Registos extends Table {
  TextColumn get tabela => text()();
  TextColumn get chave => text()();
  TextColumn get dados => text()();
  BoolColumn get apagado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {tabela, chave};
}

/// Fila persistente de alterações por enviar ao servidor.
@DataClassName('Pendente')
class Pendentes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// inserir | atualizar | rpc
  TextColumn get operacao => text()();

  /// Tabela (ou nome da função, nas rpc).
  TextColumn get alvo => text()();

  /// Linhas locais afetadas ("tabela:chave", uma por linha). Enquanto a
  /// operação estiver na fila, a receção não as substitui.
  TextColumn get chaves => text()();
  TextColumn get payload => text()();
  IntColumn get tentativas => integer().withDefault(const Constant(0))();
  TextColumn get erro => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
}

/// Pequenos valores de estado: cursores por tabela, utilizador, etc.
@DataClassName('ValorEstado')
class Estado extends Table {
  TextColumn get chave => text()();
  TextColumn get valor => text().nullable()();

  @override
  Set<Column> get primaryKey => {chave};
}

/// Tabelas guardadas em cache, pela ordem em que são puxadas.
const tabelasSync = [
  'preferencias',
  'lojas',
  'categorias',
  'artigos',
  'aliases',
  'itens_lista',
  'registos_preco',
];

/// Chave local de uma linha (id ou chave natural).
String chaveDe(String tabela, Map<String, dynamic> linha) => switch (tabela) {
  'itens_lista' => '${linha['loja_id']}|${linha['artigo_id']}',
  'aliases' =>
    '${linha['loja_id']}|${linha['texto_talao']}|${linha['artigo_id']}',
  'preferencias' => 'eu',
  _ => linha['id'] as String,
};

/// Colunas de conflito no upsert (inserir/reativar pela chave natural).
String onConflictDe(String tabela) => switch (tabela) {
  'itens_lista' => 'user_id,loja_id,artigo_id',
  'aliases' => 'user_id,loja_id,texto_talao,artigo_id',
  'preferencias' => 'user_id',
  _ => 'id',
};

/// Filtro do UPDATE no servidor para a linha com esta chave.
Map<String, Object?> filtroDe(String tabela, Map<String, dynamic> linha) =>
    switch (tabela) {
      'itens_lista' => {
        'loja_id': linha['loja_id'],
        'artigo_id': linha['artigo_id'],
      },
      'aliases' => {
        'loja_id': linha['loja_id'],
        'texto_talao': linha['texto_talao'],
        'artigo_id': linha['artigo_id'],
      },
      _ => {'id': linha['id']},
    };

/// Nas tabelas com chave natural o id é do servidor: nunca o enviamos, para
/// que reativar uma linha apagada nunca dê conflito de chave única.
bool enviaId(String tabela) =>
    tabela != 'itens_lista' && tabela != 'aliases' && tabela != 'preferencias';

@DriftDatabase(tables: [Registos, Pendentes, Estado])
class BaseLocal extends _$BaseLocal {
  BaseLocal(super.e);

  @override
  int get schemaVersion => 1;

  // ---- Registos ----------------------------------------------------------

  Stream<List<Map<String, dynamic>>> observarTabela(String tabela) =>
      (select(registos)
            ..where((r) => r.tabela.equals(tabela) & r.apagado.equals(false)))
          .watch()
          .map((l) => [for (final r in l) _json(r.dados)]);

  Future<List<Map<String, dynamic>>> lerTabela(
    String tabela, {
    bool incluirApagados = false,
  }) async {
    final q = select(registos)..where((r) => r.tabela.equals(tabela));
    if (!incluirApagados) q.where((r) => r.apagado.equals(false));
    return [for (final r in await q.get()) _json(r.dados)];
  }

  Future<Map<String, dynamic>?> lerLinha(String tabela, String chave) async {
    final r =
        await (select(registos)
              ..where((r) => r.tabela.equals(tabela) & r.chave.equals(chave)))
            .getSingleOrNull();
    return r == null ? null : _json(r.dados);
  }

  Future<void> gravarLinha(String tabela, Map<String, dynamic> linha) =>
      into(registos).insertOnConflictUpdate(
        RegistosCompanion.insert(
          tabela: tabela,
          chave: chaveDe(tabela, linha),
          dados: jsonEncode(linha),
          apagado: Value(linha['apagado_em'] != null),
        ),
      );

  Future<void> apagarLinha(String tabela, String chave) => (delete(
    registos,
  )..where((r) => r.tabela.equals(tabela) & r.chave.equals(chave))).go();

  /// Limpa a cache (não a fila nem o utilizador) e os cursores.
  Future<void> limparCache() => transaction(() async {
    await delete(registos).go();
    await (delete(estado)..where((e) => e.chave.like('cursor:%'))).go();
  });

  /// Limpa tudo, incluindo a fila (outro utilizador / sair da conta).
  Future<void> limparTudo() => transaction(() async {
    await delete(registos).go();
    await delete(pendentes).go();
    await delete(estado).go();
  });

  // ---- Fila --------------------------------------------------------------

  Future<int> enfileirar({
    required String operacao,
    required String alvo,
    required List<String> chaves,
    required Map<String, dynamic> payload,
  }) => into(pendentes).insert(
    PendentesCompanion.insert(
      operacao: operacao,
      alvo: alvo,
      chaves: chaves.join('\n'),
      payload: jsonEncode(payload),
    ),
  );

  Future<List<Pendente>> pendentesPorEnviar() =>
      (select(pendentes)
            ..where((p) => p.erro.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.id)]))
          .get();

  Stream<List<Pendente>> observarPendentes() =>
      (select(pendentes)..orderBy([(p) => OrderingTerm.asc(p.id)])).watch();

  /// "tabela:chave" das linhas com alterações ainda por enviar.
  Future<Set<String>> chavesBloqueadas() async => {
    for (final p in await pendentesPorEnviar())
      ...p.chaves.split('\n').where((c) => c.isNotEmpty),
  };

  Future<void> removerPendente(int id) =>
      (delete(pendentes)..where((p) => p.id.equals(id))).go();

  Future<void> marcarTentativa(int id, {String? erro}) => customUpdate(
    'UPDATE pendentes SET tentativas = tentativas + 1, erro = ? WHERE id = ?',
    variables: [Variable(erro), Variable(id)],
    updates: {pendentes},
  );

  // ---- Estado ------------------------------------------------------------

  Future<String?> lerEstado(String chave) async => (await (select(
    estado,
  )..where((e) => e.chave.equals(chave))).getSingleOrNull())?.valor;

  Future<void> gravarEstado(String chave, String? valor) => into(estado)
      .insertOnConflictUpdate(
        EstadoCompanion.insert(chave: chave, valor: Value(valor)),
      );

  static Map<String, dynamic> _json(String s) =>
      (jsonDecode(s) as Map).cast<String, dynamic>();
}
