/// Preferências guardadas em `preferencias.dados` e sincronizadas entre
/// dispositivos: gestos da Lista e as últimas escolhas no ecrã Lista.
library;

enum AcaoGesto {
  marcarComprado('Marcar comprado'),
  removerDaLista('Remover da lista'),
  alterarQuantidade('Alterar quantidade'),
  nada('Nada');

  const AcaoGesto(this.rotulo);
  final String rotulo;
}

enum Organizar {
  porCategoria('Por categoria'),
  porArtigo('Por artigo, A–Z');

  const Organizar(this.rotulo);
  final String rotulo;
}

enum ModoLista {
  supermercado('No supermercado'),
  planear('Planear');

  const ModoLista(this.rotulo);
  final String rotulo;
}

class Preferencias {
  const Preferencias({
    this.direita = AcaoGesto.removerDaLista,
    this.esquerda = AcaoGesto.marcarComprado,
    this.tocar = AcaoGesto.marcarComprado,
    this.lojaId,
    this.organizar = Organizar.porCategoria,
    this.modo = ModoLista.supermercado,
    this.gruposFechados = const {},
  });

  /// Deslizar para a direita / para a esquerda / tocar no artigo.
  final AcaoGesto direita;
  final AcaoGesto esquerda;
  final AcaoGesto tocar;

  /// Loja escolhida na Lista; null = "Todas as lojas".
  final String? lojaId;
  final Organizar organizar;
  final ModoLista modo;

  /// Grupos fechados na Lista (chave "loja|categoria").
  final Set<String> gruposFechados;

  bool get gestosRepetidos =>
      direita == esquerda && direita != AcaoGesto.nada;

  factory Preferencias.fromJson(Map<String, dynamic> j) {
    T enumDe<T extends Enum>(List<T> valores, Object? nome, T omissao) =>
        valores.where((v) => v.name == nome).firstOrNull ?? omissao;
    final gestos = j['gestos'] as Map<String, dynamic>? ?? const {};
    final lista = j['lista'] as Map<String, dynamic>? ?? const {};
    const o = Preferencias();
    return Preferencias(
      direita: enumDe(AcaoGesto.values, gestos['direita'], o.direita),
      esquerda: enumDe(AcaoGesto.values, gestos['esquerda'], o.esquerda),
      tocar: enumDe(AcaoGesto.values, gestos['tocar'], o.tocar),
      lojaId: lista['loja_id'] as String?,
      organizar: enumDe(Organizar.values, lista['organizar'], o.organizar),
      modo: enumDe(ModoLista.values, lista['modo'], o.modo),
      gruposFechados: {
        for (final g in lista['grupos_fechados'] as List? ?? const []) '$g',
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'gestos': {
      'direita': direita.name,
      'esquerda': esquerda.name,
      'tocar': tocar.name,
    },
    'lista': {
      'loja_id': lojaId,
      'organizar': organizar.name,
      'modo': modo.name,
      'grupos_fechados': gruposFechados.toList()..sort(),
    },
  };

  Preferencias copyWith({
    AcaoGesto? direita,
    AcaoGesto? esquerda,
    AcaoGesto? tocar,
    String? Function()? lojaId,
    Organizar? organizar,
    ModoLista? modo,
    Set<String>? gruposFechados,
  }) => Preferencias(
    direita: direita ?? this.direita,
    esquerda: esquerda ?? this.esquerda,
    tocar: tocar ?? this.tocar,
    lojaId: lojaId == null ? this.lojaId : lojaId(),
    organizar: organizar ?? this.organizar,
    modo: modo ?? this.modo,
    gruposFechados: gruposFechados ?? this.gruposFechados,
  );
}
