import 'package:cabaz_mensal/core/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Estrutura comum das páginas: cabeçalho azul (☰ em ecrã estreito, ações,
/// título, filtros e pesquisa), corpo, FAB e rodapé.
class Pagina extends StatefulWidget {
  const Pagina({
    super.key,
    required this.titulo,
    required this.corpo,
    this.acoes = const [],
    this.filtros = const [],
    this.pesquisa,
    this.botao,
    this.rodape,
  });

  final String titulo;
  final Widget corpo;
  final List<Widget> acoes;

  /// Pílulas do cabeçalho ([FiltroPilula]).
  final List<Widget> filtros;

  /// Campo de pesquisa do cabeçalho ([CampoPesquisa]).
  final Widget? pesquisa;
  final Widget? botao;

  /// Rodapé fixo; o botão flutuante fica sempre por cima dele.
  final Widget? rodape;

  /// Abaixo desta altura o cabeçalho rola com o conteúdo em vez de o esmagar
  /// (telemóvel deitado, teclado aberto).
  static const alturaMinima = 500.0;

  @override
  State<Pagina> createState() => _PaginaState();
}

class _PaginaState extends State<Pagina> {
  // Mantém o cabeçalho (e o foco da pesquisa) quando muda de fixo para a
  // rolar, por exemplo ao abrir o teclado.
  final _cabecalho = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final escopo = ShellScope.of(context);
    final faixa = escopo?.faixa;
    final cabecalho = CabecalhoPagina(
      key: _cabecalho,
      titulo: widget.titulo,
      abrirMenu: escopo?.abrirMenu,
      acoes: widget.acoes,
      filtros: widget.filtros,
      pesquisa: widget.pesquisa,
    );
    // A faixa fica por baixo do cabeçalho (nunca por baixo da barra de estado).
    final corpo = SafeArea(
      top: false,
      child: faixa == null
          ? widget.corpo
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                faixa,
                Expanded(child: widget.corpo),
              ],
            ),
    );
    return Scaffold(
      floatingActionButton: widget.botao,
      bottomNavigationBar: widget.rodape,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: LayoutBuilder(
          builder: (context, c) => c.maxHeight >= Pagina.alturaMinima
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cabecalho,
                    Expanded(child: corpo),
                  ],
                )
              : NestedScrollView(
                  headerSliverBuilder: (_, _) => [
                    SliverToBoxAdapter(child: cabecalho),
                  ],
                  body: corpo,
                ),
        ),
      ),
    );
  }
}

/// Cabeçalho em gradiente da [Pagina], com cantos arredondados em baixo e a
/// margem de cima do sistema por dentro (o azul cobre a barra de estado).
class CabecalhoPagina extends StatelessWidget {
  const CabecalhoPagina({
    super.key,
    required this.titulo,
    required this.abrirMenu,
    required this.acoes,
    required this.filtros,
    required this.pesquisa,
  });

  final String titulo;
  final VoidCallback? abrirMenu;
  final List<Widget> acoes;
  final List<Widget> filtros;
  final Widget? pesquisa;

  @override
  Widget build(BuildContext context) {
    final cores = CoresCabaz.of(context);
    final tema = Theme.of(context);
    final linhaCima = abrirMenu != null || acoes.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cores.gradienteInicio, cores.gradienteFim],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, linhaCima ? 4 : 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (linhaCima)
                // Ações brancas: o PopupMenuButton usa o IconTheme e o
                // IconButton o IconButtonTheme.
                IconTheme.merge(
                  data: IconThemeData(color: cores.sobreGradiente),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor: cores.sobreGradiente,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (abrirMenu != null)
                          IconButton(
                            icon: const Icon(Icons.menu),
                            tooltip: 'Menu',
                            onPressed: abrirMenu,
                            style: estiloBotaoSobreGradiente(cores),
                          ),
                        const Spacer(),
                        ...acoes,
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: linhaCima ? 8 : 0),
                child: Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      color: cores.sobreGradiente,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (filtros.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: filtros),
              ],
              if (pesquisa case final p?) ...[const SizedBox(height: 8), p],
            ],
          ),
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
