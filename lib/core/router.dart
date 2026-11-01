import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../data/repositorios.dart';
import '../features/artigos/artigos_page.dart';
import '../features/definicoes/definicoes_page.dart';
import '../features/entrada/entrada_page.dart';
import '../features/historico/historico_page.dart';
import '../features/importar_exportar/importar_exportar_page.dart';
import '../features/lista/lista_page.dart';
import '../features/painel/painel_page.dart';
import '../features/shell/faixa_sync.dart';
import '../features/shell/shell.dart';
import '../features/shell/tema_controlos.dart';

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

/// Onde a app abre (e para onde vai depois de entrar): o primeiro destino do
/// menu.
const rotaInicial = '/painel';

/// Regra do redirect: sem sessão só se vê a entrada; com sessão, a entrada
/// leva à [rotaInicial]. null = ficar onde está.
String? redirecionar({required bool temSessao, required String local}) {
  final naEntrada = local == '/entrar';
  if (!temSessao) return naEntrada ? null : '/entrar';
  if (naEntrada) return rotaInicial;
  return null;
}

// Usa a estratégia de URL por hash (por omissão no Flutter web): atualizar a
// página (F5) no GitHub Pages não dá 404. Não chamar usePathUrlStrategy.
GoRouter criarRouter(AuthRepository auth) {
  final ouvinte = _OuvinteSessao(auth.observarSessao());
  return GoRouter(
    initialLocation: rotaInicial,
    refreshListenable: ouvinte,
    redirect: (context, estado) =>
        redirecionar(temSessao: auth.temSessao, local: estado.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => rotaInicial),
      GoRoute(path: '/entrar', builder: (_, _) => const EntradaPage()),
      ShellRoute(
        builder: (context, estado, filho) => AppShell(
          localizacao: estado.matchedLocation,
          faixa: const FaixaSync(),
          acaoMenu: const BotaoTema(),
          child: filho,
        ),
        routes: [
          GoRoute(
            path: '/lista',
            pageBuilder: (_, _) => const NoTransitionPage(child: ListaPage()),
          ),
          GoRoute(
            path: '/painel',
            pageBuilder: (_, _) => const NoTransitionPage(child: PainelPage()),
          ),
          GoRoute(
            path: '/historico',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: HistoricoPage()),
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
