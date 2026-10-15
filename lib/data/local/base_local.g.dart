// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_local.dart';

// ignore_for_file: type=lint
class $RegistosTable extends Registos
    with TableInfo<$RegistosTable, RegistoLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegistosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tabelaMeta = const VerificationMeta('tabela');
  @override
  late final GeneratedColumn<String> tabela = GeneratedColumn<String>(
    'tabela',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chaveMeta = const VerificationMeta('chave');
  @override
  late final GeneratedColumn<String> chave = GeneratedColumn<String>(
    'chave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosMeta = const VerificationMeta('dados');
  @override
  late final GeneratedColumn<String> dados = GeneratedColumn<String>(
    'dados',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apagadoMeta = const VerificationMeta(
    'apagado',
  );
  @override
  late final GeneratedColumn<bool> apagado = GeneratedColumn<bool>(
    'apagado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("apagado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [tabela, chave, dados, apagado];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registos';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegistoLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tabela')) {
      context.handle(
        _tabelaMeta,
        tabela.isAcceptableOrUnknown(data['tabela']!, _tabelaMeta),
      );
    } else if (isInserting) {
      context.missing(_tabelaMeta);
    }
    if (data.containsKey('chave')) {
      context.handle(
        _chaveMeta,
        chave.isAcceptableOrUnknown(data['chave']!, _chaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chaveMeta);
    }
    if (data.containsKey('dados')) {
      context.handle(
        _dadosMeta,
        dados.isAcceptableOrUnknown(data['dados']!, _dadosMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosMeta);
    }
    if (data.containsKey('apagado')) {
      context.handle(
        _apagadoMeta,
        apagado.isAcceptableOrUnknown(data['apagado']!, _apagadoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tabela, chave};
  @override
  RegistoLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistoLocal(
      tabela: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabela'],
      )!,
      chave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chave'],
      )!,
      dados: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dados'],
      )!,
      apagado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}apagado'],
      )!,
    );
  }

  @override
  $RegistosTable createAlias(String alias) {
    return $RegistosTable(attachedDatabase, alias);
  }
}

class RegistoLocal extends DataClass implements Insertable<RegistoLocal> {
  final String tabela;
  final String chave;
  final String dados;
  final bool apagado;
  const RegistoLocal({
    required this.tabela,
    required this.chave,
    required this.dados,
    required this.apagado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tabela'] = Variable<String>(tabela);
    map['chave'] = Variable<String>(chave);
    map['dados'] = Variable<String>(dados);
    map['apagado'] = Variable<bool>(apagado);
    return map;
  }

  RegistosCompanion toCompanion(bool nullToAbsent) {
    return RegistosCompanion(
      tabela: Value(tabela),
      chave: Value(chave),
      dados: Value(dados),
      apagado: Value(apagado),
    );
  }

  factory RegistoLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistoLocal(
      tabela: serializer.fromJson<String>(json['tabela']),
      chave: serializer.fromJson<String>(json['chave']),
      dados: serializer.fromJson<String>(json['dados']),
      apagado: serializer.fromJson<bool>(json['apagado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tabela': serializer.toJson<String>(tabela),
      'chave': serializer.toJson<String>(chave),
      'dados': serializer.toJson<String>(dados),
      'apagado': serializer.toJson<bool>(apagado),
    };
  }

  RegistoLocal copyWith({
    String? tabela,
    String? chave,
    String? dados,
    bool? apagado,
  }) => RegistoLocal(
    tabela: tabela ?? this.tabela,
    chave: chave ?? this.chave,
    dados: dados ?? this.dados,
    apagado: apagado ?? this.apagado,
  );
  RegistoLocal copyWithCompanion(RegistosCompanion data) {
    return RegistoLocal(
      tabela: data.tabela.present ? data.tabela.value : this.tabela,
      chave: data.chave.present ? data.chave.value : this.chave,
      dados: data.dados.present ? data.dados.value : this.dados,
      apagado: data.apagado.present ? data.apagado.value : this.apagado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistoLocal(')
          ..write('tabela: $tabela, ')
          ..write('chave: $chave, ')
          ..write('dados: $dados, ')
          ..write('apagado: $apagado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tabela, chave, dados, apagado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistoLocal &&
          other.tabela == this.tabela &&
          other.chave == this.chave &&
          other.dados == this.dados &&
          other.apagado == this.apagado);
}

class RegistosCompanion extends UpdateCompanion<RegistoLocal> {
  final Value<String> tabela;
  final Value<String> chave;
  final Value<String> dados;
  final Value<bool> apagado;
  final Value<int> rowid;
  const RegistosCompanion({
    this.tabela = const Value.absent(),
    this.chave = const Value.absent(),
    this.dados = const Value.absent(),
    this.apagado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegistosCompanion.insert({
    required String tabela,
    required String chave,
    required String dados,
    this.apagado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tabela = Value(tabela),
       chave = Value(chave),
       dados = Value(dados);
  static Insertable<RegistoLocal> custom({
    Expression<String>? tabela,
    Expression<String>? chave,
    Expression<String>? dados,
    Expression<bool>? apagado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tabela != null) 'tabela': tabela,
      if (chave != null) 'chave': chave,
      if (dados != null) 'dados': dados,
      if (apagado != null) 'apagado': apagado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegistosCompanion copyWith({
    Value<String>? tabela,
    Value<String>? chave,
    Value<String>? dados,
    Value<bool>? apagado,
    Value<int>? rowid,
  }) {
    return RegistosCompanion(
      tabela: tabela ?? this.tabela,
      chave: chave ?? this.chave,
      dados: dados ?? this.dados,
      apagado: apagado ?? this.apagado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tabela.present) {
      map['tabela'] = Variable<String>(tabela.value);
    }
    if (chave.present) {
      map['chave'] = Variable<String>(chave.value);
    }
    if (dados.present) {
      map['dados'] = Variable<String>(dados.value);
    }
    if (apagado.present) {
      map['apagado'] = Variable<bool>(apagado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegistosCompanion(')
          ..write('tabela: $tabela, ')
          ..write('chave: $chave, ')
          ..write('dados: $dados, ')
          ..write('apagado: $apagado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendentesTable extends Pendentes
    with TableInfo<$PendentesTable, Pendente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendentesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operacaoMeta = const VerificationMeta(
    'operacao',
  );
  @override
  late final GeneratedColumn<String> operacao = GeneratedColumn<String>(
    'operacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alvoMeta = const VerificationMeta('alvo');
  @override
  late final GeneratedColumn<String> alvo = GeneratedColumn<String>(
    'alvo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chavesMeta = const VerificationMeta('chaves');
  @override
  late final GeneratedColumn<String> chaves = GeneratedColumn<String>(
    'chaves',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tentativasMeta = const VerificationMeta(
    'tentativas',
  );
  @override
  late final GeneratedColumn<int> tentativas = GeneratedColumn<int>(
    'tentativas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _erroMeta = const VerificationMeta('erro');
  @override
  late final GeneratedColumn<String> erro = GeneratedColumn<String>(
    'erro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operacao,
    alvo,
    chaves,
    payload,
    tentativas,
    erro,
    criadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pendentes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pendente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operacao')) {
      context.handle(
        _operacaoMeta,
        operacao.isAcceptableOrUnknown(data['operacao']!, _operacaoMeta),
      );
    } else if (isInserting) {
      context.missing(_operacaoMeta);
    }
    if (data.containsKey('alvo')) {
      context.handle(
        _alvoMeta,
        alvo.isAcceptableOrUnknown(data['alvo']!, _alvoMeta),
      );
    } else if (isInserting) {
      context.missing(_alvoMeta);
    }
    if (data.containsKey('chaves')) {
      context.handle(
        _chavesMeta,
        chaves.isAcceptableOrUnknown(data['chaves']!, _chavesMeta),
      );
    } else if (isInserting) {
      context.missing(_chavesMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('tentativas')) {
      context.handle(
        _tentativasMeta,
        tentativas.isAcceptableOrUnknown(data['tentativas']!, _tentativasMeta),
      );
    }
    if (data.containsKey('erro')) {
      context.handle(
        _erroMeta,
        erro.isAcceptableOrUnknown(data['erro']!, _erroMeta),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pendente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pendente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operacao'],
      )!,
      alvo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alvo'],
      )!,
      chaves: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chaves'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      tentativas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tentativas'],
      )!,
      erro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}erro'],
      ),
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
    );
  }

  @override
  $PendentesTable createAlias(String alias) {
    return $PendentesTable(attachedDatabase, alias);
  }
}

class Pendente extends DataClass implements Insertable<Pendente> {
  final int id;

  /// inserir | atualizar | rpc
  final String operacao;

  /// Tabela (ou nome da função, nas rpc).
  final String alvo;

  /// Linhas locais afetadas ("tabela:chave", uma por linha). Enquanto a
  /// operação estiver na fila, a receção não as substitui.
  final String chaves;
  final String payload;
  final int tentativas;
  final String? erro;
  final DateTime criadoEm;
  const Pendente({
    required this.id,
    required this.operacao,
    required this.alvo,
    required this.chaves,
    required this.payload,
    required this.tentativas,
    this.erro,
    required this.criadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operacao'] = Variable<String>(operacao);
    map['alvo'] = Variable<String>(alvo);
    map['chaves'] = Variable<String>(chaves);
    map['payload'] = Variable<String>(payload);
    map['tentativas'] = Variable<int>(tentativas);
    if (!nullToAbsent || erro != null) {
      map['erro'] = Variable<String>(erro);
    }
    map['criado_em'] = Variable<DateTime>(criadoEm);
    return map;
  }

  PendentesCompanion toCompanion(bool nullToAbsent) {
    return PendentesCompanion(
      id: Value(id),
      operacao: Value(operacao),
      alvo: Value(alvo),
      chaves: Value(chaves),
      payload: Value(payload),
      tentativas: Value(tentativas),
      erro: erro == null && nullToAbsent ? const Value.absent() : Value(erro),
      criadoEm: Value(criadoEm),
    );
  }

  factory Pendente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pendente(
      id: serializer.fromJson<int>(json['id']),
      operacao: serializer.fromJson<String>(json['operacao']),
      alvo: serializer.fromJson<String>(json['alvo']),
      chaves: serializer.fromJson<String>(json['chaves']),
      payload: serializer.fromJson<String>(json['payload']),
      tentativas: serializer.fromJson<int>(json['tentativas']),
      erro: serializer.fromJson<String?>(json['erro']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operacao': serializer.toJson<String>(operacao),
      'alvo': serializer.toJson<String>(alvo),
      'chaves': serializer.toJson<String>(chaves),
      'payload': serializer.toJson<String>(payload),
      'tentativas': serializer.toJson<int>(tentativas),
      'erro': serializer.toJson<String?>(erro),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
    };
  }

  Pendente copyWith({
    int? id,
    String? operacao,
    String? alvo,
    String? chaves,
    String? payload,
    int? tentativas,
    Value<String?> erro = const Value.absent(),
    DateTime? criadoEm,
  }) => Pendente(
    id: id ?? this.id,
    operacao: operacao ?? this.operacao,
    alvo: alvo ?? this.alvo,
    chaves: chaves ?? this.chaves,
    payload: payload ?? this.payload,
    tentativas: tentativas ?? this.tentativas,
    erro: erro.present ? erro.value : this.erro,
    criadoEm: criadoEm ?? this.criadoEm,
  );
  Pendente copyWithCompanion(PendentesCompanion data) {
    return Pendente(
      id: data.id.present ? data.id.value : this.id,
      operacao: data.operacao.present ? data.operacao.value : this.operacao,
      alvo: data.alvo.present ? data.alvo.value : this.alvo,
      chaves: data.chaves.present ? data.chaves.value : this.chaves,
      payload: data.payload.present ? data.payload.value : this.payload,
      tentativas: data.tentativas.present
          ? data.tentativas.value
          : this.tentativas,
      erro: data.erro.present ? data.erro.value : this.erro,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pendente(')
          ..write('id: $id, ')
          ..write('operacao: $operacao, ')
          ..write('alvo: $alvo, ')
          ..write('chaves: $chaves, ')
          ..write('payload: $payload, ')
          ..write('tentativas: $tentativas, ')
          ..write('erro: $erro, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operacao,
    alvo,
    chaves,
    payload,
    tentativas,
    erro,
    criadoEm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pendente &&
          other.id == this.id &&
          other.operacao == this.operacao &&
          other.alvo == this.alvo &&
          other.chaves == this.chaves &&
          other.payload == this.payload &&
          other.tentativas == this.tentativas &&
          other.erro == this.erro &&
          other.criadoEm == this.criadoEm);
}

class PendentesCompanion extends UpdateCompanion<Pendente> {
  final Value<int> id;
  final Value<String> operacao;
  final Value<String> alvo;
  final Value<String> chaves;
  final Value<String> payload;
  final Value<int> tentativas;
  final Value<String?> erro;
  final Value<DateTime> criadoEm;
  const PendentesCompanion({
    this.id = const Value.absent(),
    this.operacao = const Value.absent(),
    this.alvo = const Value.absent(),
    this.chaves = const Value.absent(),
    this.payload = const Value.absent(),
    this.tentativas = const Value.absent(),
    this.erro = const Value.absent(),
    this.criadoEm = const Value.absent(),
  });
  PendentesCompanion.insert({
    this.id = const Value.absent(),
    required String operacao,
    required String alvo,
    required String chaves,
    required String payload,
    this.tentativas = const Value.absent(),
    this.erro = const Value.absent(),
    this.criadoEm = const Value.absent(),
  }) : operacao = Value(operacao),
       alvo = Value(alvo),
       chaves = Value(chaves),
       payload = Value(payload);
  static Insertable<Pendente> custom({
    Expression<int>? id,
    Expression<String>? operacao,
    Expression<String>? alvo,
    Expression<String>? chaves,
    Expression<String>? payload,
    Expression<int>? tentativas,
    Expression<String>? erro,
    Expression<DateTime>? criadoEm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operacao != null) 'operacao': operacao,
      if (alvo != null) 'alvo': alvo,
      if (chaves != null) 'chaves': chaves,
      if (payload != null) 'payload': payload,
      if (tentativas != null) 'tentativas': tentativas,
      if (erro != null) 'erro': erro,
      if (criadoEm != null) 'criado_em': criadoEm,
    });
  }

  PendentesCompanion copyWith({
    Value<int>? id,
    Value<String>? operacao,
    Value<String>? alvo,
    Value<String>? chaves,
    Value<String>? payload,
    Value<int>? tentativas,
    Value<String?>? erro,
    Value<DateTime>? criadoEm,
  }) {
    return PendentesCompanion(
      id: id ?? this.id,
      operacao: operacao ?? this.operacao,
      alvo: alvo ?? this.alvo,
      chaves: chaves ?? this.chaves,
      payload: payload ?? this.payload,
      tentativas: tentativas ?? this.tentativas,
      erro: erro ?? this.erro,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operacao.present) {
      map['operacao'] = Variable<String>(operacao.value);
    }
    if (alvo.present) {
      map['alvo'] = Variable<String>(alvo.value);
    }
    if (chaves.present) {
      map['chaves'] = Variable<String>(chaves.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (tentativas.present) {
      map['tentativas'] = Variable<int>(tentativas.value);
    }
    if (erro.present) {
      map['erro'] = Variable<String>(erro.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendentesCompanion(')
          ..write('id: $id, ')
          ..write('operacao: $operacao, ')
          ..write('alvo: $alvo, ')
          ..write('chaves: $chaves, ')
          ..write('payload: $payload, ')
          ..write('tentativas: $tentativas, ')
          ..write('erro: $erro, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }
}

class $EstadoTable extends Estado with TableInfo<$EstadoTable, ValorEstado> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EstadoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chaveMeta = const VerificationMeta('chave');
  @override
  late final GeneratedColumn<String> chave = GeneratedColumn<String>(
    'chave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [chave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'estado';
  @override
  VerificationContext validateIntegrity(
    Insertable<ValorEstado> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chave')) {
      context.handle(
        _chaveMeta,
        chave.isAcceptableOrUnknown(data['chave']!, _chaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chaveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chave};
  @override
  ValorEstado map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ValorEstado(
      chave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      ),
    );
  }

  @override
  $EstadoTable createAlias(String alias) {
    return $EstadoTable(attachedDatabase, alias);
  }
}

class ValorEstado extends DataClass implements Insertable<ValorEstado> {
  final String chave;
  final String? valor;
  const ValorEstado({required this.chave, this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chave'] = Variable<String>(chave);
    if (!nullToAbsent || valor != null) {
      map['valor'] = Variable<String>(valor);
    }
    return map;
  }

  EstadoCompanion toCompanion(bool nullToAbsent) {
    return EstadoCompanion(
      chave: Value(chave),
      valor: valor == null && nullToAbsent
          ? const Value.absent()
          : Value(valor),
    );
  }

  factory ValorEstado.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ValorEstado(
      chave: serializer.fromJson<String>(json['chave']),
      valor: serializer.fromJson<String?>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chave': serializer.toJson<String>(chave),
      'valor': serializer.toJson<String?>(valor),
    };
  }

  ValorEstado copyWith({
    String? chave,
    Value<String?> valor = const Value.absent(),
  }) => ValorEstado(
    chave: chave ?? this.chave,
    valor: valor.present ? valor.value : this.valor,
  );
  ValorEstado copyWithCompanion(EstadoCompanion data) {
    return ValorEstado(
      chave: data.chave.present ? data.chave.value : this.chave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ValorEstado(')
          ..write('chave: $chave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValorEstado &&
          other.chave == this.chave &&
          other.valor == this.valor);
}

class EstadoCompanion extends UpdateCompanion<ValorEstado> {
  final Value<String> chave;
  final Value<String?> valor;
  final Value<int> rowid;
  const EstadoCompanion({
    this.chave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EstadoCompanion.insert({
    required String chave,
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chave = Value(chave);
  static Insertable<ValorEstado> custom({
    Expression<String>? chave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chave != null) 'chave': chave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EstadoCompanion copyWith({
    Value<String>? chave,
    Value<String?>? valor,
    Value<int>? rowid,
  }) {
    return EstadoCompanion(
      chave: chave ?? this.chave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chave.present) {
      map['chave'] = Variable<String>(chave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EstadoCompanion(')
          ..write('chave: $chave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BaseLocal extends GeneratedDatabase {
  _$BaseLocal(QueryExecutor e) : super(e);
  $BaseLocalManager get managers => $BaseLocalManager(this);
  late final $RegistosTable registos = $RegistosTable(this);
  late final $PendentesTable pendentes = $PendentesTable(this);
  late final $EstadoTable estado = $EstadoTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    registos,
    pendentes,
    estado,
  ];
}

typedef $$RegistosTableCreateCompanionBuilder = RegistosCompanion Function({
  required String tabela,
  required String chave,
  required String dados,
  Value<bool> apagado,
  Value<int> rowid,
});
typedef $$RegistosTableUpdateCompanionBuilder = RegistosCompanion Function({
  Value<String> tabela,
  Value<String> chave,
  Value<String> dados,
  Value<bool> apagado,
  Value<int> rowid,
});

class $$RegistosTableFilterComposer
    extends Composer<_$BaseLocal, $RegistosTable> {
  $$RegistosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get apagado => $composableBuilder(
    column: $table.apagado,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RegistosTableOrderingComposer
    extends Composer<_$BaseLocal, $RegistosTable> {
  $$RegistosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get apagado => $composableBuilder(
    column: $table.apagado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RegistosTableAnnotationComposer
    extends Composer<_$BaseLocal, $RegistosTable> {
  $$RegistosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tabela =>
      $composableBuilder(column: $table.tabela, builder: (column) => column);

  GeneratedColumn<String> get chave =>
      $composableBuilder(column: $table.chave, builder: (column) => column);

  GeneratedColumn<String> get dados =>
      $composableBuilder(column: $table.dados, builder: (column) => column);

  GeneratedColumn<bool> get apagado =>
      $composableBuilder(column: $table.apagado, builder: (column) => column);
}

class $$RegistosTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $RegistosTable,
          RegistoLocal,
          $$RegistosTableFilterComposer,
          $$RegistosTableOrderingComposer,
          $$RegistosTableAnnotationComposer,
          $$RegistosTableCreateCompanionBuilder,
          $$RegistosTableUpdateCompanionBuilder,
          (
            RegistoLocal,
            BaseReferences<_$BaseLocal, $RegistosTable, RegistoLocal>,
          ),
          RegistoLocal,
          PrefetchHooks Function()
        > {
  $$RegistosTableTableManager(_$BaseLocal db, $RegistosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegistosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegistosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegistosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tabela = const Value.absent(),
                Value<String> chave = const Value.absent(),
                Value<String> dados = const Value.absent(),
                Value<bool> apagado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegistosCompanion(
                tabela: tabela,
                chave: chave,
                dados: dados,
                apagado: apagado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tabela,
                required String chave,
                required String dados,
                Value<bool> apagado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegistosCompanion.insert(
                tabela: tabela,
                chave: chave,
                dados: dados,
                apagado: apagado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RegistosTable, RegistoLocal>(table),
                  BaseReferences<_$BaseLocal, $RegistosTable, RegistoLocal>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RegistosTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $RegistosTable,
      RegistoLocal,
      $$RegistosTableFilterComposer,
      $$RegistosTableOrderingComposer,
      $$RegistosTableAnnotationComposer,
      $$RegistosTableCreateCompanionBuilder,
      $$RegistosTableUpdateCompanionBuilder,
      (RegistoLocal, BaseReferences<_$BaseLocal, $RegistosTable, RegistoLocal>),
      RegistoLocal,
      PrefetchHooks Function()
    >;
typedef $$PendentesTableCreateCompanionBuilder = PendentesCompanion Function({
  Value<int> id,
  required String operacao,
  required String alvo,
  required String chaves,
  required String payload,
  Value<int> tentativas,
  Value<String?> erro,
  Value<DateTime> criadoEm,
});
typedef $$PendentesTableUpdateCompanionBuilder = PendentesCompanion Function({
  Value<int> id,
  Value<String> operacao,
  Value<String> alvo,
  Value<String> chaves,
  Value<String> payload,
  Value<int> tentativas,
  Value<String?> erro,
  Value<DateTime> criadoEm,
});

class $$PendentesTableFilterComposer
    extends Composer<_$BaseLocal, $PendentesTable> {
  $$PendentesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alvo => $composableBuilder(
    column: $table.alvo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaves => $composableBuilder(
    column: $table.chaves,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get erro => $composableBuilder(
    column: $table.erro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendentesTableOrderingComposer
    extends Composer<_$BaseLocal, $PendentesTable> {
  $$PendentesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alvo => $composableBuilder(
    column: $table.alvo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaves => $composableBuilder(
    column: $table.chaves,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get erro => $composableBuilder(
    column: $table.erro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendentesTableAnnotationComposer
    extends Composer<_$BaseLocal, $PendentesTable> {
  $$PendentesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operacao =>
      $composableBuilder(column: $table.operacao, builder: (column) => column);

  GeneratedColumn<String> get alvo =>
      $composableBuilder(column: $table.alvo, builder: (column) => column);

  GeneratedColumn<String> get chaves =>
      $composableBuilder(column: $table.chaves, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => column,
  );

  GeneratedColumn<String> get erro =>
      $composableBuilder(column: $table.erro, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);
}

class $$PendentesTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $PendentesTable,
          Pendente,
          $$PendentesTableFilterComposer,
          $$PendentesTableOrderingComposer,
          $$PendentesTableAnnotationComposer,
          $$PendentesTableCreateCompanionBuilder,
          $$PendentesTableUpdateCompanionBuilder,
          (Pendente, BaseReferences<_$BaseLocal, $PendentesTable, Pendente>),
          Pendente,
          PrefetchHooks Function()
        > {
  $$PendentesTableTableManager(_$BaseLocal db, $PendentesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendentesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendentesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendentesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operacao = const Value.absent(),
                Value<String> alvo = const Value.absent(),
                Value<String> chaves = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> tentativas = const Value.absent(),
                Value<String?> erro = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => PendentesCompanion(
                id: id,
                operacao: operacao,
                alvo: alvo,
                chaves: chaves,
                payload: payload,
                tentativas: tentativas,
                erro: erro,
                criadoEm: criadoEm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operacao,
                required String alvo,
                required String chaves,
                required String payload,
                Value<int> tentativas = const Value.absent(),
                Value<String?> erro = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => PendentesCompanion.insert(
                id: id,
                operacao: operacao,
                alvo: alvo,
                chaves: chaves,
                payload: payload,
                tentativas: tentativas,
                erro: erro,
                criadoEm: criadoEm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendentesTable, Pendente>(table),
                  BaseReferences<_$BaseLocal, $PendentesTable, Pendente>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendentesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $PendentesTable,
      Pendente,
      $$PendentesTableFilterComposer,
      $$PendentesTableOrderingComposer,
      $$PendentesTableAnnotationComposer,
      $$PendentesTableCreateCompanionBuilder,
      $$PendentesTableUpdateCompanionBuilder,
      (Pendente, BaseReferences<_$BaseLocal, $PendentesTable, Pendente>),
      Pendente,
      PrefetchHooks Function()
    >;
typedef $$EstadoTableCreateCompanionBuilder = EstadoCompanion Function({
  required String chave,
  Value<String?> valor,
  Value<int> rowid,
});
typedef $$EstadoTableUpdateCompanionBuilder = EstadoCompanion Function({
  Value<String> chave,
  Value<String?> valor,
  Value<int> rowid,
});

class $$EstadoTableFilterComposer extends Composer<_$BaseLocal, $EstadoTable> {
  $$EstadoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EstadoTableOrderingComposer
    extends Composer<_$BaseLocal, $EstadoTable> {
  $$EstadoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EstadoTableAnnotationComposer
    extends Composer<_$BaseLocal, $EstadoTable> {
  $$EstadoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chave =>
      $composableBuilder(column: $table.chave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$EstadoTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $EstadoTable,
          ValorEstado,
          $$EstadoTableFilterComposer,
          $$EstadoTableOrderingComposer,
          $$EstadoTableAnnotationComposer,
          $$EstadoTableCreateCompanionBuilder,
          $$EstadoTableUpdateCompanionBuilder,
          (ValorEstado, BaseReferences<_$BaseLocal, $EstadoTable, ValorEstado>),
          ValorEstado,
          PrefetchHooks Function()
        > {
  $$EstadoTableTableManager(_$BaseLocal db, $EstadoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EstadoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EstadoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EstadoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> chave = const Value.absent(),
            Value<String?> valor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => EstadoCompanion(chave: chave, valor: valor, rowid: rowid),
          createCompanionCallback:
              ({
                required String chave,
                Value<String?> valor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EstadoCompanion.insert(
                chave: chave,
                valor: valor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EstadoTable, ValorEstado>(table),
                  BaseReferences<_$BaseLocal, $EstadoTable, ValorEstado>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EstadoTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $EstadoTable,
      ValorEstado,
      $$EstadoTableFilterComposer,
      $$EstadoTableOrderingComposer,
      $$EstadoTableAnnotationComposer,
      $$EstadoTableCreateCompanionBuilder,
      $$EstadoTableUpdateCompanionBuilder,
      (ValorEstado, BaseReferences<_$BaseLocal, $EstadoTable, ValorEstado>),
      ValorEstado,
      PrefetchHooks Function()
    >;

class $BaseLocalManager {
  final _$BaseLocal _db;
  $BaseLocalManager(this._db);
  $$RegistosTableTableManager get registos =>
      $$RegistosTableTableManager(_db, _db.registos);
  $$PendentesTableTableManager get pendentes =>
      $$PendentesTableTableManager(_db, _db.pendentes);
  $$EstadoTableTableManager get estado =>
      $$EstadoTableTableManager(_db, _db.estado);
}
