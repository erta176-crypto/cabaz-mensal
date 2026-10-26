import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ponto único de corte entre telemóvel e ecrã largo.
const larguraEcraLargo = 800.0;

class Destino {
  const Destino({
    required this.caminho,
    required this.rotulo,
    required this.rotuloCurto,
    required this.icone,
    required this.iconeSelecionado,
    required this.naBarraInferior,
  });

  final String caminho;
  final String rotulo; // menu lateral
  final String rotuloCurto; // barra inferior e título
  final IconData icone;
  final IconData iconeSelecionado;
  final bool naBarraInferior;
}

const destinos = <Destino>[
  Destino(
    caminho: '/lista',
    rotulo: 'Lista do mês',
    rotuloCurto: 'Lista',
    icone: Icons.checklist_outlined,
    iconeSelecionado: Icons.checklist,
    naBarraInferior: true,
  ),
  Destino(
    caminho: '/painel',
    rotulo: 'Painel e estatísticas',
    rotuloCurto: 'Painel',
    icone: Icons.insights_outlined,
    iconeSelecionado: Icons.insights,
    naBarraInferior: true,
  ),
  Destino(
    caminho: '/historico',
    rotulo: 'Histórico',
    rotuloCurto: 'Histórico',
    icone: Icons.receipt_long_outlined,
    iconeSelecionado: Icons.receipt_long,
    naBarraInferior: true,
  ),
  Destino(
    caminho: '/artigos',
    rotulo: 'Artigos, categorias e lojas',
    rotuloCurto: 'Artigos',
    icone: Icons.inventory_2_outlined,
    iconeSelecionado: Icons.inventory_2,
    naBarraInferior: true,
  ),
  Destino(
    caminho: '/importar',
    rotulo: 'Importar e exportar',
    rotuloCurto: 'Importar e exportar',
    icone: Icons.import_export_outlined,
    iconeSelecionado: Icons.import_export,
    naBarraInferior: false,
  ),
  Destino(
    caminho: '/definicoes',
    rotulo: 'Definições',
    rotuloCurto: 'Definições',
    icone: Icons.settings_outlined,
    iconeSelecionado: Icons.settings,
    naBarraInferior: false,
  ),
];

final destinosBarraInferior = [
  for (final d in destinos)
    if (d.naBarraInferior) d,
];

int indiceDestino(String localizacao) {
  final i = destinos.indexWhere((d) => localizacao.startsWith(d.caminho));
  return i < 0 ? 0 : i;
}

/// Dá às páginas acesso ao botão ☰ (só existe em ecrã estreito).
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.abrirMenu,
    this.faixa,
    required super.child,
  });

  final VoidCallback? abrirMenu;

  /// Faixa mostrada por baixo do título de cada página (sincronização).
  final Widget? faixa;

  static ShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) =>
      old.abrirMenu != abrirMenu || old.faixa != faixa;
}

/// Estrutura de navegação:
/// - < 800 px: barra inferior (4 destinos) + menu lateral modal (☰, 6 destinos).
/// - ≥ 800 px: menu lateral fixo à esquerda (6 destinos), sem barra nem ☰.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.localizacao,
    required this.child,
    this.faixa,
    this.acaoMenu,
  });

  final String localizacao;
  final Widget child;

  /// Faixa por cima do conteúdo (estado da sincronização).
  final Widget? faixa;

  /// Ação à direita do nome no topo do menu lateral (botão do tema).
  final Widget? acaoMenu;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _chave = GlobalKey<ScaffoldState>();

  void _ir(int indice) {
    _chave.currentState?.closeDrawer();
    context.go(destinos[indice].caminho);
  }

  @override
  Widget build(BuildContext context) {
    final atual = indiceDestino(widget.localizacao);
    final largo = MediaQuery.sizeOf(context).width >= larguraEcraLargo;

    final menu = NavigationDrawer(
      selectedIndex: atual,
      onDestinationSelected: _ir,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 16),
          child: Row(
            children: [
              Icon(
                Icons.shopping_basket,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cabaz Mensal',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?widget.acaoMenu,
            ],
          ),
        ),
        for (final d in destinos)
          NavigationDrawerDestination(
            icon: Icon(d.icone),
            selectedIcon: Icon(d.iconeSelecionado),
            // Largura fixa: o rótulo corta com "…" em vez de transbordar.
            label: SizedBox(
              width: 196,
              child: Text(
                d.rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );

    if (largo) {
      return Scaffold(
        key: _chave,
        body: Row(
          children: [
            SizedBox(width: 300, child: menu),
            const VerticalDivider(width: 1),
            Expanded(
              child: ShellScope(
                abrirMenu: null,
                faixa: widget.faixa,
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }

    final noBarra = destinosBarraInferior.indexOf(destinos[atual]);
    return Scaffold(
      key: _chave,
      drawer: menu,
      body: ShellScope(
        abrirMenu: () => _chave.currentState?.openDrawer(),
        faixa: widget.faixa,
        child: widget.child,
      ),
      // Importar e Definições só estão no menu ☰; aí a barra fica escondida
      // porque não tem nenhum destino para marcar como selecionado.
      bottomNavigationBar: noBarra < 0
          ? null
          : NavigationBar(
              selectedIndex: noBarra,
              onDestinationSelected: (i) =>
                  _ir(destinos.indexOf(destinosBarraInferior[i])),
              destinations: [
                for (final d in destinosBarraInferior)
                  NavigationDestination(
                    icon: Icon(d.icone),
                    selectedIcon: Icon(d.iconeSelecionado),
                    label: d.rotuloCurto,
                  ),
              ],
            ),
    );
  }
}

/// Estrutura comum das páginas: título, ☰ em ecrã estreito, ações e FAB.
class Pagina extends StatelessWidget {
  const Pagina({
    super.key,
    required this.titulo,
    required this.corpo,
    this.acoes = const [],
    this.botao,
    this.rodape,
  });

  final String titulo;
  final Widget corpo;
  final List<Widget> acoes;
  final Widget? botao;

  /// Rodapé fixo; o botão flutuante fica sempre por cima dele.
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final escopo = ShellScope.of(context);
    final abrirMenu = escopo?.abrirMenu;
    final faixa = escopo?.faixa;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: abrirMenu == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: abrirMenu,
              ),
        title: Text(titulo),
        actions: acoes,
      ),
      floatingActionButton: botao,
      bottomNavigationBar: rodape,
      // A faixa fica por baixo do título (nunca por baixo da barra de estado).
      body: SafeArea(
        top: false,
        child: faixa == null
            ? corpo
            : Column(
                children: [
                  faixa,
                  Expanded(child: corpo),
                ],
              ),
      ),
    );
  }
}

/// Limita a largura do conteúdo em ecrãs largos.
class ConteudoCentrado extends StatelessWidget {
  const ConteudoCentrado({super.key, required this.child, this.largura = 960});

  final Widget child;
  final double largura;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: largura),
      child: child,
    ),
  );
}
