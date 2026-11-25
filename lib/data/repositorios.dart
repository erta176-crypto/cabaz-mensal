/// Contratos da camada de dados. A interface só conhece estes tipos.
///
/// Desde a Fase 1A as leituras vêm da cache local (drift), atualizada pela
/// sincronização, e as escritas vão para a cache + fila de alterações. Assim
/// a Lista funciona sem rede no supermercado.
library;

import '../domain/compra.dart';
import '../domain/estatisticas.dart';
import '../domain/modelos.dart';
import '../domain/orcamento.dart';
import '../domain/preferencias.dart';

abstract interface class AuthRepository {
  bool get temSessao;
  String? get email;
  String? get utilizadorId;

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
  /// Todas as lojas não eliminadas, incluindo as arquivadas.
  Stream<List<Loja>> observarLojas();

  /// Cria ([nova]) ou atualiza. Criar com o nome de uma loja eliminada
  /// reativa-a.
  Future<void> guardar(Loja loja, {bool nova = false});

  Future<void> arquivar(String id, {required bool arquivada});

  /// Só elimina lojas sem compras. Lança [ErroDados] se tiver compras ou se
  /// não houver rede para o confirmar.
  Future<void> eliminar(String id);
}

abstract interface class CategoriasRepository {
  Stream<List<Categoria>> observarCategorias();

  /// Criar com o nome de uma categoria eliminada reativa-a. Lança
  /// [ErroNomeRepetido] se já há uma ativa com o mesmo nome.
  Future<void> criar({required String nome, required int ordem});

  /// Lança [ErroNomeRepetido] se o nome é o de outra categoria, ativa ou
  /// eliminada (o índice único do servidor inclui as eliminadas).
  Future<void> atualizar(Categoria categoria);

  /// Junta [origemId] a [destinoId]: os artigos passam para o destino
  /// (reativado, se estava eliminado) e a origem é eliminada.
  Future<void> juntar(String origemId, String destinoId);

  /// Elimina a categoria. Os artigos que tinha passam para [moverPara]
  /// (ou ficam sem categoria, se for null).
  Future<void> eliminar(String id, {String? moverPara});

  /// Categorias eliminadas (para reativar a mesma linha, com o mesmo id).
  Future<List<Categoria>> apagadas();
}

abstract interface class ArtigosRepository {
  Stream<List<Artigo>> observarArtigos();
  Stream<List<PrecoAtual>> observarPrecosAtuais();

  /// Textos de talão por artigo (para a pesquisa).
  Stream<Map<String, List<String>>> observarAliases();

  /// Guarda um texto de talão como alias do artigo nessa loja (da próxima
  /// importação liga sozinho). Gravar um alias que já existe não duplica.
  Future<void> guardarAlias(String lojaId, String textoTalao, String artigoId);

  /// Registos de preço de um artigo (não apagados), por data crescente.
  Stream<List<RegistoPreco>> observarRegistos(String artigoId);

  /// Cria ou atualiza o artigo. [precosCent] tem o preço por loja (id da loja);
  /// só os preços que mudaram geram um novo registo de preço 'manual'.
  Future<void> guardar(
    Artigo artigo, {
    Map<String, int?> precosCent = const {},
    bool novo = false,
  });

  Future<void> eliminar(String id);

  /// Artigos eliminados (para reativar a mesma linha, com o mesmo id).
  Future<List<Artigo>> apagados();
}

/// Orçamento mensal (total e por categoria), sincronizado.
abstract interface class OrcamentosRepository {
  /// Todos os orçamentos não apagados (de todos os meses).
  Stream<List<Orcamento>> observar();

  /// Define o orçamento de [categoriaId] (null = total) no mês de [mes];
  /// [valorCent] null apaga-o.
  Future<void> definir(DateTime mes, String? categoriaId, int? valorCent);

  /// Copia para o mês [para] os orçamentos do mês [de].
  Future<void> copiar(DateTime de, DateTime para);
}

abstract interface class ListaRepository {
  /// Itens da lista (todas as lojas), incluídos ou não.
  Stream<List<ItemLista>> observarItens();

  /// Junta o artigo à lista da loja (ou reativa-o), com [qtd] ou a
  /// quantidade habitual.
  Future<void> incluir({
    required String lojaId,
    required String artigoId,
    num? qtd,
  });

  Future<void> marcarComprado(ItemLista item, {required bool comprado});
  Future<void> alterarQtd(ItemLista item, num qtd);
  Future<void> alterarQtdPadrao(ItemLista item, num qtd);

  /// false = "Remover da lista" (continua nos artigos habituais da loja).
  Future<void> definirIncluido(ItemLista item, {required bool incluido});

  /// Volta a pôr o item como estava (para "Anular").
  Future<void> repor(ItemLista anterior);
}

abstract interface class PreferenciasRepository {
  Stream<Preferencias> observar();
  Future<void> guardar(Preferencias preferencias);
}

abstract interface class ComprasRepository {
  Future<int> contarCompras();

  /// Grava a compra (ou deixa-a na fila se não houver rede) e limpa os
  /// comprados dessa loja na lista.
  Future<void> concluir(CompraNova compra);

  /// Locais já usados nas compras desta loja (com cache para sem rede).
  Future<List<String>> locaisUsados(String lojaId);

  /// Pergunta ao servidor. Lança [ErroDados] se não houver rede.
  Future<int> comprasDaLoja(String lojaId);
}

/// Resultado devolvido pela RPC importar_seed.
class ContagensImportacao {
  const ContagensImportacao(this.valores);
  final Map<String, int> valores;

  int operator [](String chave) => valores[chave] ?? 0;
}

/// Números atuais no servidor (cartão "Resumo dos dados").
class ResumoDados {
  const ResumoDados({
    required this.nCompras,
    required this.nArtigos,
    required this.lojas,
  });

  final int nCompras;
  final int nArtigos;
  final List<ResumoLoja> lojas;

  int get totalCent => lojas.fold(0, (s, l) => s + l.totalCent);
}

/// Operações que vão sempre diretas ao servidor.
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

  Future<List<ResumoLoja>> resumoPorLoja();

  Future<ResumoDados> resumoDados();

  /// Grava um lote importado de ficheiro numa só transação (RPC
  /// importar_lote). Devolve as contagens por tabela.
  Future<Map<String, int>> importarLote(Map<String, dynamic> payload);

  /// Compras já gravadas e não eliminadas (para detetar repetidas ao
  /// importar).
  Future<List<({String lojaId, String data, String? local, int totalCent})>>
  comprasExistentes();

  /// Elimina um talão (marca `apagado_em`; só com rede). Fase 15.
  Future<void> eliminarCompra(String id);

  /// Repõe um talão eliminado ("Anular"; só com rede). Fase 15.
  Future<void> reporCompra(String id);
}

class EstadoSync {
  const EstadoSync({
    this.online = true,
    this.aSincronizar = false,
    this.pendentes = 0,
    this.comErro = 0,
    this.ultimoErro,
    this.ultimaSincronizacao,
  });

  final bool online;

  /// Diagnóstico: último erro da sincronização e quando correu bem pela
  /// última vez (mostrados no diálogo "Alterações por enviar").
  final String? ultimoErro;
  final DateTime? ultimaSincronizacao;
  final bool aSincronizar;

  /// Alterações à espera de serem enviadas.
  final int pendentes;

  /// Alterações que o servidor recusou (ficam visíveis até descartar).
  final int comErro;

  EstadoSync copyWith({
    bool? online,
    bool? aSincronizar,
    int? pendentes,
    int? comErro,
    String? Function()? ultimoErro,
    DateTime? ultimaSincronizacao,
  }) => EstadoSync(
    online: online ?? this.online,
    aSincronizar: aSincronizar ?? this.aSincronizar,
    pendentes: pendentes ?? this.pendentes,
    comErro: comErro ?? this.comErro,
    ultimoErro: ultimoErro == null ? this.ultimoErro : ultimoErro(),
    ultimaSincronizacao: ultimaSincronizacao ?? this.ultimaSincronizacao,
  );
}

class AlteracaoPendente {
  const AlteracaoPendente({
    required this.id,
    required this.descricao,
    required this.tentativas,
    this.erro,
  });

  final int id;
  final String descricao;
  final int tentativas;
  final String? erro;
}

abstract interface class SyncRepository {
  Stream<EstadoSync> observarEstado();
  Stream<List<AlteracaoPendente>> observarPendentes();
  Future<void> sincronizar();

  /// Volta a tentar também as alterações com erro e sincroniza.
  Future<void> tentarDeNovo();

  /// Descarta uma alteração recusada e volta a carregar o que ela afetava.
  Future<void> descartar(int id);

  /// Limpa a cache e volta a puxar tudo (ex.: depois de importar).
  /// Com [descartarPendentes], descarta também a fila (ex.: Apagar tudo).
  Future<void> recarregarTudo({bool descartarPendentes = false});

  /// Apaga tudo o que está neste dispositivo (ao sair da conta).
  Future<void> limparLocal();
}

/// Painel e histórico de compras. Os totais são calculados no servidor.
abstract interface class EstatisticasRepository {
  /// Painel do filtro. Com rede: chama a RPC e guarda na cache. Sem rede:
  /// devolve a cache (com `guardadoEm`) se for do mesmo intervalo; senão lança
  /// [ErroDados]. [hoje] só existe para os testes.
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje});

  /// Compras do filtro (só com rede). [artigoIds] e [texto] filtram por linha.
  Future<List<CompraResumo>> compras(
    FiltroCompras filtro, {
    List<String>? artigoIds,
    String? texto,
    DateTime? hoje,
  });

  /// Linhas de uma compra (só com rede).
  Future<List<LinhaCompra>> linhas(String compraId);

  /// Artigos de uma barra do Painel, no período do [filtro] (só com rede).
  /// Loja: [lojaId], ou a do filtro. Categorias: [categoriaIds] e/ou
  /// [semCategoria]; sem nenhum, todas (barra de uma loja).
  Future<DetalhePainel> artigosDoPainel(
    FiltroCompras filtro, {
    String? lojaId,
    List<String>? categoriaIds,
    bool semCategoria = false,
    DateTime? hoje,
  });
}

/// Erro de dados com mensagem pronta a mostrar ao utilizador.
class ErroDados implements Exception {
  const ErroDados(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Nome de categoria igual ao de [existente] (sem contar espaços nas pontas,
/// maiúsculas e acentos). [apagada]: [existente] está eliminada.
class ErroNomeRepetido extends ErroDados {
  ErroNomeRepetido(this.existente, {required this.apagada})
    : super(
        apagada
            ? 'Já existe a categoria "${existente.nome}" (eliminada).'
            : 'Já existe a categoria "${existente.nome}".',
      );

  final Categoria existente;
  final bool apagada;
}

/// Uma escrita no servidor passou do tempo: o pedido pode ter sido
/// concluído na mesma, por isso não se deve repetir sem confirmar.
class ErroSemResposta extends ErroDados {
  const ErroSemResposta()
    : super(
        'O servidor não respondeu a tempo; a operação pode ter ficado '
        'gravada. Confirma no resumo antes de repetir.',
      );
}
