import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/modelos.dart';
import 'repositorios.dart';
import 'supabase/supabase_repositorios.dart';

/// Único ponto onde o cliente Supabase entra na árvore. Nos testes, os
/// providers dos repositórios são substituídos por versões em memória.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final lojasRepositoryProvider = Provider<LojasRepository>(
  (ref) => SupabaseLojasRepository(ref.watch(supabaseClientProvider)),
);

final categoriasRepositoryProvider = Provider<CategoriasRepository>(
  (ref) => SupabaseCategoriasRepository(ref.watch(supabaseClientProvider)),
);

final artigosRepositoryProvider = Provider<ArtigosRepository>(
  (ref) => SupabaseArtigosRepository(ref.watch(supabaseClientProvider)),
);

final comprasRepositoryProvider = Provider<ComprasRepository>(
  (ref) => SupabaseComprasRepository(ref.watch(supabaseClientProvider)),
);

final dadosRepositoryProvider = Provider<DadosRepository>(
  (ref) => SupabaseDadosRepository(ref.watch(supabaseClientProvider)),
);

/// Email do utilizador com sessão (null sem sessão). Os streams de dados
/// dependem dele para recomeçarem quando se entra com outra conta.
final sessaoProvider = StreamProvider<String?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return auth.observarSessao().map((_) => auth.email);
});

final lojasProvider = StreamProvider<List<Loja>>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(lojasRepositoryProvider).observarLojas();
});

final categoriasProvider = StreamProvider<List<Categoria>>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(categoriasRepositoryProvider).observarCategorias();
});

final artigosProvider = StreamProvider<List<Artigo>>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(artigosRepositoryProvider).observarArtigos();
});

final precosAtuaisProvider = StreamProvider<List<PrecoAtual>>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(artigosRepositoryProvider).observarPrecosAtuais();
});
