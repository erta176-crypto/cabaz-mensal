import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../data/repositorios.dart';
import '../features/artigos/artigos_page.dart';
import '../features/definicoes/definicoes_page.dart';
import '../features/em_breve/em_breve_page.dart';
import '../features/entrada/entrada_page.dart';
import '../features/importar_exportar/importar_exportar_page.dart';
import '../features/lista/lista_page.dart';
import '../features/shell/faixa_sync.dart';
import '../features/shell/shell.dart';

/// Avisa o go_router quando a sessão muda, para reavaliar o redirect.
class _OuvinteSessao extends ChangeNotifier {
  _OuvinteSessao(Stream<bool> sessao) {
    _sub = sessao.listen((_) => notifyListeners());
  }
  late final StreamSubscription<bool> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Usa a estratégia de URL por hash (por omissão no Flutter web): atualizar a
// página (F5) no GitHub Pages não dá 404. Não chamar usePathUrlStrategy.
GoRouter criarRouter(AuthRepository auth) {
  final ouvinte = _OuvinteSessao(auth.observarSessao());
  return GoRouter(
    initialLocation: '/lista',
    refreshListenable: ouvinte,
    redirect: (context, estado) {
      final naEntrada = estado.matchedLocation == '/entrar';
      if (!auth.temSessao) return naEntrada ? null : '/entrar';
      if (naEntrada) return '/lista';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/lista'),
      GoRoute(path: '/entrar', builder: (_, _) => const EntradaPage()),
      ShellRoute(
        builder: (context, estado, filho) => AppShell(
          localizacao: estado.matchedLocation,
          faixa: const FaixaSync(),
          child: filho,
        ),
        routes: [
          GoRoute(
            path: '/lista',
            pageBuilder: (_, _) => const NoTransitionPage(child: ListaPage()),
          ),
          GoRoute(
            path: '/painel',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: EmBrevePage(titulo: 'Painel e estatísticas', fase: 2),
            ),
          ),
          GoRoute(
            path: '/historico',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: EmBrevePage(titulo: 'Histórico', fase: 2),
            ),
          ),
          GoRoute(
            path: '/artigos',
            pageBuilder: (_, _) => const NoTransitionPage(child: ArtigosPage()),
          ),
          GoRoute(
            path: '/importar',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ImportarExportarPage()),
          ),
          GoRoute(
            path: '/definicoes',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DefinicoesPage()),
          ),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = criarRouter(ref.watch(authRepositoryProvider));
  ref.onDispose(router.dispose);
  return router;
});
