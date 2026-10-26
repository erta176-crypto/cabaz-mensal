import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/estatisticas.dart';
import '../domain/modelos.dart';
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
