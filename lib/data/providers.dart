import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/desbloqueio.dart';
import '../domain/estatisticas.dart';
import '../domain/modelos.dart';
import '../domain/orcamento.dart';
import '../domain/preferencias.dart';
import 'local/abrir_base.dart';
import 'local/base_local.dart';
import 'local/repositorios_locais.dart';
import 'repositorios.dart';
import 'supabase/supabase_estatisticas.dart';
import 'supabase/supabase_repositorios.dart';
import 'sync/escrita.dart';
import 'sync/rede.dart';
import 'sync/servidor.dart';
import 'sync/servidor_supabase.dart';
import 'sync/sincronizador.dart';
import 'sync/sync_repository.dart';

/// Único ponto onde o cliente Supabase entra na árvore. Nos testes, os
/// providers dos repositórios são substituídos por versões em memória.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Email do utilizador com sessão (null sem sessão).
final sessaoProvider = StreamProvider<String?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return auth.observarSessao().map((_) => auth.email);
});

final utilizadorIdProvider = Provider<String?>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(authRepositoryProvider).utilizadorId;
});

// ---- Cache local e sincronização ------------------------------------------

final baseLocalProvider = Provider<BaseLocal>((ref) {
  final base = abrirBaseLocal();
  ref.onDispose(base.close);
  return base;
});

final servidorSyncProvider = Provider<ServidorSync>(
  (ref) => ServidorSupabase(ref.watch(supabaseClientProvider)),
);

final redeProvider = Provider<Stream<bool>>((ref) => observarRede());

/// Um sincronizador por sessão; termina ao sair da conta.
final sincronizadorProvider = Provider<Sincronizador?>((ref) {
  final uid = ref.watch(utilizadorIdProvider);
  if (uid == null) return null;
  final s = Sincronizador(
    base: ref.watch(baseLocalProvider),
    servidor: ref.watch(servidorSyncProvider),
    utilizadorId: uid,
    rede: ref.watch(redeProvider),
  );
  s.iniciar();
  ref.onDispose(s.fechar);
  return s;
});

final escritaProvider = Provider<Escrita>((ref) {
  final escrita = Escrita(ref.watch(baseLocalProvider));
  escrita.aposEscrever = () => ref.read(sincronizadorProvider)?.sincronizar();
  return escrita;
});

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => LocalSyncRepository(
    ref.watch(baseLocalProvider),
    ref.watch(sincronizadorProvider),
  ),
);

// ---- Tema (só neste aparelho) ---------------------------------------------

final temaProvider = NotifierProvider<TemaNotifier, ModoTema>(TemaNotifier.new);

/// Tema escolhido neste aparelho, guardado na tabela `estado` (chave `tema`).
class TemaNotifier extends Notifier<ModoTema> {
  /// Uma escolha feita antes de a leitura inicial acabar prevalece.
  bool _escolhido = false;

  @override
  ModoTema build() {
    ref.read(baseLocalProvider).lerEstado('tema').then((v) {
      if (!ref.mounted || _escolhido) return;
      state =
          ModoTema.values.where((m) => m.name == v).firstOrNull ??
          ModoTema.sistema;
    });
    return ModoTema.sistema;
  }

  Future<void> escolher(ModoTema m) async {
    _escolhido = true;
    state = m;
    await ref.read(baseLocalProvider).gravarEstado('tema', m.name);
  }
}

// ---- Bloqueio (só neste aparelho) -----------------------------------------

final bloqueioProvider = AsyncNotifierProvider<BloqueioNotifier, bool>(
  BloqueioNotifier.new,
);

/// Bloqueio com biometria ou PIN ligado neste aparelho (Fase 8, D4), na
/// tabela `estado` (chave `bloqueio`). Sair da conta desliga-o (`limparTudo`
/// só guarda o tema).
class BloqueioNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(baseLocalProvider).lerEstado('bloqueio') == 'sim';

  /// Só liga depois de um desbloqueio com êxito, para ninguém ficar fora da
  /// app. Devolve se ficou ligado; lança [ErroDesbloqueio].
  Future<bool> ligar() async {
    if (!await ref.read(desbloqueioProvider).pedir()) return false;
    await ref.read(baseLocalProvider).gravarEstado('bloqueio', 'sim');
    state = const AsyncData(true);
    return true;
  }

  Future<void> desligar() async {
    await ref.read(baseLocalProvider).gravarEstado('bloqueio', null);
    state = const AsyncData(false);
  }
}

// ---- Repositórios ---------------------------------------------------------

final consultasComprasProvider = Provider<ConsultasCompras>(
  (ref) => SupabaseConsultasCompras(ref.watch(supabaseClientProvider)),
);

final lojasRepositoryProvider = Provider<LojasRepository>(
  (ref) => LocalLojasRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
    compras: ref.watch(consultasComprasProvider).comprasDaLoja,
  ),
);

final categoriasRepositoryProvider = Provider<CategoriasRepository>(
  (ref) => LocalCategoriasRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
  ),
);

final artigosRepositoryProvider = Provider<ArtigosRepository>(
  (ref) => LocalArtigosRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
  ),
);

final orcamentosRepositoryProvider = Provider<OrcamentosRepository>(
  (ref) => LocalOrcamentosRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
    ref.watch(utilizadorIdProvider) ?? '',
  ),
);

final listaRepositoryProvider = Provider<ListaRepository>(
  (ref) => LocalListaRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
  ),
);

final preferenciasRepositoryProvider = Provider<PreferenciasRepository>(
  (ref) => LocalPreferenciasRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
  ),
);

final comprasRepositoryProvider = Provider<ComprasRepository>(
  (ref) => LocalComprasRepository(
    ref.watch(baseLocalProvider),
    ref.watch(escritaProvider),
    ref.watch(consultasComprasProvider),
  ),
);

final estatisticasRepositoryProvider = Provider<EstatisticasRepository>((ref) {
  final cliente = ref.watch(supabaseClientProvider);
  return SupabaseEstatisticasRepository(
    rpc: (nome, params) => cliente.rpc(nome, params: params),
    lerLinhas: (id) =>
        cliente.from('linhas_compra').select().eq('compra_id', id),
    base: ref.watch(baseLocalProvider),
  );
});

final dadosRepositoryProvider = Provider<DadosRepository>(
  (ref) => SupabaseDadosRepository(ref.watch(supabaseClientProvider)),
);

// ---- Streams para os ecrãs ------------------------------------------------

final lojasProvider = StreamProvider<List<Loja>>(
  (ref) => ref.watch(lojasRepositoryProvider).observarLojas(),
);

final categoriasProvider = StreamProvider<List<Categoria>>(
  (ref) => ref.watch(categoriasRepositoryProvider).observarCategorias(),
);

final artigosProvider = StreamProvider<List<Artigo>>(
  (ref) => ref.watch(artigosRepositoryProvider).observarArtigos(),
);

final precosAtuaisProvider = StreamProvider<List<PrecoAtual>>(
  (ref) => ref.watch(artigosRepositoryProvider).observarPrecosAtuais(),
);

final aliasesProvider = StreamProvider<Map<String, List<String>>>(
  (ref) => ref.watch(artigosRepositoryProvider).observarAliases(),
);

final registosPrecoProvider = StreamProvider.autoDispose
    .family<List<RegistoPreco>, String>(
      (ref, artigoId) =>
          ref.watch(artigosRepositoryProvider).observarRegistos(artigoId),
    );

final painelProvider = FutureProvider.autoDispose
    .family<ResultadoPainel, FiltroCompras>(
      (ref, filtro) => ref.watch(estatisticasRepositoryProvider).painel(filtro),
    );

/// Linhas de uma compra (só com rede).
final linhasCompraProvider = FutureProvider.autoDispose
    .family<List<LinhaCompra>, String>(
      (ref, compraId) =>
          ref.watch(estatisticasRepositoryProvider).linhas(compraId),
    );

final orcamentosProvider = StreamProvider<List<Orcamento>>(
  (ref) => ref.watch(orcamentosRepositoryProvider).observar(),
);

final itensListaProvider = StreamProvider<List<ItemLista>>(
  (ref) => ref.watch(listaRepositoryProvider).observarItens(),
);

final preferenciasProvider = StreamProvider<Preferencias>(
  (ref) => ref.watch(preferenciasRepositoryProvider).observar(),
);

final estadoSyncProvider = StreamProvider<EstadoSync>(
  (ref) => ref.watch(syncRepositoryProvider).observarEstado(),
);

final pendentesProvider = StreamProvider<List<AlteracaoPendente>>(
  (ref) => ref.watch(syncRepositoryProvider).observarPendentes(),
);

/// Os providers de que o catálogo de uma importação precisa. O ecrã que
/// importa tem de os ouvir no build: sem ninguém a ouvir, um provider ainda
/// não tem valor (e no Riverpod 3 é descartado enquanto carrega), e a análise
/// corria com os aliases ou os artigos vazios.
final providersDoCatalogo = <ProviderListenable<AsyncValue<Object>>>[
  lojasProvider,
  categoriasProvider,
  artigosProvider,
  aliasesProvider,
  precosAtuaisProvider,
  itensListaProvider,
];

/// Espera que os dados do catálogo (cache local) tenham valor. Os providers
/// têm de estar a ser ouvidos ([providersDoCatalogo]).
Future<void> carregarCatalogo(T Function<T>(ProviderListenable<T>) ler) =>
    Future.wait([
      ler(lojasProvider.future),
      ler(categoriasProvider.future),
      ler(artigosProvider.future),
      ler(aliasesProvider.future),
      ler(precosAtuaisProvider.future),
      ler(itensListaProvider.future),
    ]);
