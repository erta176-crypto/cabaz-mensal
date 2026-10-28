import 'package:cabaz_mensal/core/tema.dart';
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
    caminho: '/painel',
    rotulo: 'Painel e estatísticas',
    rotuloCurto: 'Painel',
    icone: Icons.insights_outlined,
    iconeSelecionado: Icons.insights,
    naBarraInferior: true,
  ),
  Destino(
    caminho: '/lista',
    rotulo: 'Lista do mês',
    rotuloCurto: 'Lista',
    icone: Icons.checklist_outlined,
    iconeSelecionado: Icons.checklist,
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

    final cores = CoresCabaz.of(context);
    final esquema = Theme.of(context).colorScheme;
    // O gradiente vai até ao topo: o NavigationDrawer deixa de receber a
    // margem de cima (SafeArea) e o cabeçalho põe-na por dentro. No ecrã
    // largo a margem da direita (barra do sistema) é do conteúdo, não do menu.
    final menu = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeRight: largo,
      child: NavigationDrawer(
        selectedIndex: atual,
        onDestinationSelected: _ir,
        header: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cores.gradienteInicio, cores.gradienteFim],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 8,
              12,
              8,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shopping_basket, color: esquema.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cabaz Mensal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cores.sobreGradiente,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?widget.acaoMenu,
              ],
            ),
          ),
        ),
        children: [
          const SizedBox(height: 12),
          for (final d in destinos) ...[
            if (d.caminho == '/importar')
              const Divider(indent: 28, endIndent: 28),
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
        ],
      ),
    );

    if (largo) {
      return Scaffold(
        key: _chave,
        body: Row(
          children: [
            // Telemóvel deitado: a margem da esquerda (recorte da câmara)
            // soma-se aos 300 px, porque o NavigationDrawer tira-a.
            SizedBox(
              width: 300 + MediaQuery.paddingOf(context).left,
              child: menu,
            ),
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
          : DecoratedBox(
              // O tema da NavigationBar não tem contorno.
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: esquema.outlineVariant)),
              ),
              child: NavigationBar(
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
    final cores = CoresCabaz.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        // O AppBar dá ao flexibleSpace uma altura solta: sem o expand, o
        // DecoratedBox (sem filho) ficava com altura 0.
        flexibleSpace: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cores.gradienteInicio, cores.gradienteFim],
              ),
            ),
          ),
        ),
        leading: abrirMenu == null
            ? null
            : Center(
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: abrirMenu,
                  style: estiloBotaoSobreGradiente(cores),
                ),
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

/// Filtros no topo e a lista por baixo. Com pouca altura (telemóvel deitado,
/// teclado aberto) os filtros sobem com a lista em vez de a esmagarem.
class FiltrosEConteudo extends StatelessWidget {
  const FiltrosEConteudo({
    super.key,
    required this.filtros,
    required this.conteudo,
  });

  final Widget filtros;

  /// Normalmente uma lista com scroll (sem controlador próprio).
  final Widget conteudo;

  /// Abaixo desta altura os filtros deixam de ficar fixos.
  static const alturaMinima = 420.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxHeight >= alturaMinima
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filtros,
              Expanded(child: conteudo),
            ],
          )
        : NestedScrollView(
            headerSliverBuilder: (_, _) => [SliverToBoxAdapter(child: filtros)],
            body: conteudo,
          ),
  );
}
