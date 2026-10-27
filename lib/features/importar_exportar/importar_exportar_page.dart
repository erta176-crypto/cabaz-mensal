import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ficheiros/guardar_ficheiro.dart';
import '../../core/ficheiros/largar_ficheiro.dart';
import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../data/repositorios.dart';
import '../../domain/modelos.dart';
import '../../export/dados_export.dart';
import '../../export/escrever_pdf.dart';
import '../../export/tabela_export.dart';
import '../../export/texto_lista.dart';
import '../../import/analisar_artigos.dart';
import '../../import/analisar_compras.dart';
import '../../import/analisar_lista.dart';
import '../../import/campos.dart';
import '../../import/exportar.dart';
import '../../import/importar_seed.dart';
import '../../import/previsualizacao.dart';
import '../../import/seed_modelo.dart';
import '../../import/tabela_lida.dart';
import '../../import/taloes/importar_taloes.dart';
import '../../import/taloes/ler_pdfs.dart';
import '../../import/taloes/texto_pdf.dart';
import '../lista/lista_logica.dart' show formatarQtd;
import '../shell/shell.dart';
import 'previsualizacao_card.dart';
import 'previsualizacao_taloes.dart';

/// O mesmo menu para importar e exportar.
enum OQue {
  artigos('Artigos e preços', 'artigos'),
  compras('Compras e linhas', 'compras'),
  lista('Lista de compras', 'lista'),
  copia('Cópia completa', 'copia'),
  taloes('Talões (PDF)', 'taloes');

  const OQue(this.rotulo, this.slug);
  final String rotulo;
  final String slug;

  TipoImportacao? get tipo => switch (this) {
    OQue.artigos => TipoImportacao.artigos,
    OQue.compras => TipoImportacao.compras,
    OQue.lista => TipoImportacao.lista,
    OQue.copia || OQue.taloes => null,
  };

  List<Formato> get paraImportar => switch (this) {
    OQue.copia => const [Formato.json],
    OQue.taloes => const [Formato.pdf],
    _ => const [Formato.csv, Formato.xlsx],
  };

  List<Formato> get paraExportar => switch (this) {
    OQue.artigos => const [Formato.xlsx, Formato.csv, Formato.pdf],
    OQue.compras => const [Formato.xlsx, Formato.csv],
    OQue.lista => const [Formato.xlsx, Formato.csv, Formato.pdf, Formato.txt],
    OQue.copia => const [Formato.json],
    OQue.taloes => const [],
  };
}

/// Leitura do texto dos PDFs (substituída nos testes).
final lerTextoPdfProvider = Provider<LerTextoPdf>((_) => textoDoPdf);

enum Formato {
  xlsx('Excel (.xlsx)', 'xlsx'),
  csv('CSV', 'csv'),
  pdf('PDF', 'pdf'),
  txt('TXT', 'txt'),
  json('JSON', 'json');

  const Formato(this.rotulo, this.extensao);
  final String rotulo;
  final String extensao;
}

class ImportarExportarPage extends ConsumerStatefulWidget {
  const ImportarExportarPage({super.key});

  @override
  ConsumerState<ImportarExportarPage> createState() =>
      _ImportarExportarPageState();
}

class _ImportarExportarPageState extends ConsumerState<ImportarExportarPage> {
  // ---- Importar ----
  OQue _oQue = OQue.artigos;
  bool _ocupado = false;
  int _versaoResumo = 0;
  String? _estado;
  ResultadoImportacao? _resultado;

  // Ficheiro em pré-visualização.
  String? _nome;
  Uint8List? _bytes;
  TabelaLida? _tabela;
  List<Campo> _campos = const [];
  Previsualizacao? _previa;
  List<Artigo> _artigosApagados = const [];
  List<Categoria> _categoriasApagadas = const [];
  List<CompraExistente> _existentes = const [];
  bool _semExistentes = false;
  bool _atualizarExistentes = true;
  String? _lojaSemSupermercado;
  bool _incluirSemQuantidade = false;

  // Talões (PDF) em pré-visualização.
  List<TalaoAnalisado>? _taloes;
  List<NaoReconhecido> _naoReconhecidos = const [];
  Map<String, EscolhaArtigo> _escolhas = const {};

  // ---- Exportar ----
  OQue _oQueExportar = OQue.artigos;
  Formato _formatoExportar = Formato.xlsx;
  Periodo _periodo = Periodo.tudo;
  String? _lojaExportar;

  void _mostrar(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  // ---------------------------------------------------------------------------
  // Importar ficheiros (CSV / XLSX)
  // ---------------------------------------------------------------------------

  Future<void> _escolherFicheiro() async {
    final ficheiros = await FilePicker.pickFiles(
      dialogTitle: 'Escolher ficheiro',
      type: FileType.custom,
      allowedExtensions: [for (final f in _oQue.paraImportar) f.extensao],
    );
    if (ficheiros.isEmpty || !mounted) return;
    if (_oQue == OQue.taloes) {
      return _abrirTaloes([
        for (final f in ficheiros) (nome: f.name, bytes: await f.readAsBytes()),
      ]);
    }
    final f = ficheiros.first;
    await _abrir(f.name, await f.readAsBytes());
  }

  /// Ficheiros largados: PDFs vão para os talões; outro ficheiro, o primeiro.
  void _largar(List<({String nome, Uint8List bytes})> ficheiros) {
    if (_ocupado || ficheiros.isEmpty) return;
    final pdfs = [
      for (final f in ficheiros)
        if (f.nome.toLowerCase().endsWith('.pdf')) f,
    ];
    if (pdfs.isEmpty) {
      _abrir(ficheiros.first.nome, ficheiros.first.bytes);
      return;
    }
    if (_oQue != OQue.taloes) setState(() => _oQue = OQue.taloes);
    _abrirTaloes(pdfs);
  }

  Future<void> _abrirTaloes(
    List<({String nome, Uint8List bytes})> ficheiros,
  ) async {
    _cancelarPrevia();
    setState(() {
      _ocupado = true;
      _estado = 'A ler ${ficheiros.length} PDF…';
    });
    try {
      final lidos = await lerPdfs(
        ficheiros,
        ref.read(lerTextoPdfProvider),
        progresso: (i, n) {
          if (mounted) setState(() => _estado = 'A ler ${i + 1} de $n…');
        },
      );
      final List<CompraExistente> existentes;
      try {
        existentes = [
          for (final c
              in await ref.read(dadosRepositoryProvider).comprasExistentes())
            CompraExistente(
              lojaId: c.lojaId,
              data: DateTime.parse(c.data),
              local: c.local,
              totalCent: c.totalCent,
            ),
        ];
      } catch (_) {
        if (mounted) setState(() => _estado = null);
        _mostrar('Sem rede: a importação de talões precisa do servidor.');
        return;
      }
      _artigosApagados = await ref.read(artigosRepositoryProvider).apagados();
      _categoriasApagadas = await ref
          .read(categoriasRepositoryProvider)
          .apagadas();
      await carregarCatalogo(ref.read);
      if (!mounted) return;
      final r = analisarTaloes(lidos.lidos, _catalogo(), existentes);
      setState(() {
        _taloes = r.taloes;
        _naoReconhecidos = [...lidos.ilegiveis, ...r.naoReconhecidos];
        _escolhas = {};
        _estado = null;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _gravarTaloes() async {
    final taloes = _taloes!;
    setState(() => _ocupado = true);
    try {
      final lote = loteDosTaloes(taloes, _escolhas, _catalogo());
      await ref.read(dadosRepositoryProvider).importarLote(lote.toJson());
      await ref.read(syncRepositoryProvider).recarregarTudo();
      if (!mounted) return;
      final n = lote.compras.length;
      _mostrar(
        'Importados $n ${n == 1 ? 'talão' : 'talões'} '
        '(${lote.linhas.length} linhas).',
      );
      _cancelarPrevia();
      setState(() => _versaoResumo++);
    } catch (e) {
      _mostrar('A importação falhou e nada foi alterado: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir(String nome, Uint8List bytes) async {
    if (nome.toLowerCase().endsWith('.pdf')) {
      if (_oQue != OQue.taloes) setState(() => _oQue = OQue.taloes);
      return _abrirTaloes([(nome: nome, bytes: bytes)]);
    }
    if (nome.toLowerCase().endsWith('.json')) {
      if (_oQue != OQue.copia) setState(() => _oQue = OQue.copia);
      return _importarJson(nome, bytes);
    }
    if (_oQue == OQue.copia) {
      _mostrar('A cópia completa é um ficheiro .json.');
      return;
    }
    setState(() {
      _ocupado = true;
      _estado = 'A ler $nome…';
    });
    try {
      final tabela = lerFicheiro(nome, bytes);
      final tipo = _oQue.tipo!;
      var existentes = const <CompraExistente>[];
      var semExistentes = false;
      if (tipo == TipoImportacao.compras) {
        try {
          existentes = [
            for (final c
                in await ref.read(dadosRepositoryProvider).comprasExistentes())
              CompraExistente(
                lojaId: c.lojaId,
                data: DateTime.parse(c.data),
                local: c.local,
                totalCent: c.totalCent,
              ),
          ];
        } catch (_) {
          semExistentes = true;
        }
      }
      final artigosApagados = await ref
          .read(artigosRepositoryProvider)
          .apagados();
      final categoriasApagadas = await ref
          .read(categoriasRepositoryProvider)
          .apagadas();
      await carregarCatalogo(ref.read);
      if (!mounted) return;
      setState(() {
        _nome = nome;
        _bytes = bytes;
        _tabela = tabela;
        _campos = adivinharColunas(tabela.cabecalhos, tipo);
        _existentes = existentes;
        _semExistentes = semExistentes;
        _artigosApagados = artigosApagados;
        _categoriasApagadas = categoriasApagadas;
        _resultado = null;
        _estado = null;
      });
      _recalcular();
    } on FicheiroInvalido catch (e) {
      if (mounted) setState(() => _estado = null);
      _mostrar('$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _mudarFolha(String folha) {
    final tabela = lerFicheiro(_nome!, _bytes!, folha: folha);
    setState(() {
      _tabela = tabela;
      _campos = adivinharColunas(tabela.cabecalhos, _oQue.tipo!);
    });
    _recalcular();
  }

  Catalogo _catalogo() => Catalogo(
    lojas: [
      for (final l in ref.read(lojasProvider).value ?? const <Loja>[])
        if (!l.arquivada) l,
    ],
    categorias: ref.read(categoriasProvider).value ?? const [],
    artigos: ref.read(artigosProvider).value ?? const [],
    categoriasApagadas: _categoriasApagadas,
    artigosApagados: _artigosApagados,
    aliases: ref.read(aliasesProvider).value ?? const {},
    precos: ref.read(precosAtuaisProvider).value ?? const [],
    itens: ref.read(itensListaProvider).value ?? const [],
  );

  void _recalcular() {
    final tabela = _tabela;
    if (tabela == null) return;
    final cat = _catalogo();
    final previa = switch (_oQue.tipo!) {
      TipoImportacao.artigos => analisarArtigos(
        tabela,
        _campos,
        cat,
        atualizarExistentes: _atualizarExistentes,
      ),
      TipoImportacao.compras => analisarCompras(
        tabela,
        _campos,
        cat,
        _existentes,
      ),
      TipoImportacao.lista => analisarLista(
        tabela,
        _campos,
        cat,
        lojaPorOmissao: cat.lojas
            .where((l) => l.id == _lojaSemSupermercado)
            .firstOrNull,
        incluirSemQuantidade: _incluirSemQuantidade,
      ),
    };
    setState(() => _previa = previa);
  }

  void _cancelarPrevia() => setState(() {
    _nome = null;
    _bytes = null;
    _tabela = null;
    _previa = null;
    _taloes = null;
    _naoReconhecidos = const [];
    _escolhas = const {};
  });

  Future<void> _gravarLote() async {
    final previa = _previa!;
    setState(() => _ocupado = true);
    try {
      await ref
          .read(dadosRepositoryProvider)
          .importarLote(previa.lote.toJson());
      await ref.read(syncRepositoryProvider).recarregarTudo();
      if (!mounted) return;
      _mostrar('Importadas ${previa.aImportar} linhas.');
      _cancelarPrevia();
      setState(() => _versaoResumo++);
    } catch (e) {
      _mostrar('A importação falhou e nada foi alterado: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  List<Widget> _opcoesDoTipo() {
    final lojas = [
      for (final l in ref.watch(lojasProvider).value ?? const <Loja>[])
        if (!l.arquivada) l,
    ];
    final tabela = _tabela!;
    return [
      if (tabela.folhas.length > 1)
        DropdownMenu<String>(
          key: ValueKey('folha-${tabela.folha}'),
          label: const Text('Folha'),
          width: 200,
          initialSelection: tabela.folha,
          onSelected: (f) => f == null ? null : _mudarFolha(f),
          dropdownMenuEntries: [
            for (final f in tabela.folhas)
              DropdownMenuEntry(value: f, label: f),
          ],
        ),
      if (_oQue == OQue.artigos)
        DropdownMenu<bool>(
          label: const Text('Se o artigo já existir'),
          width: 300,
          initialSelection: _atualizarExistentes,
          onSelected: (v) {
            _atualizarExistentes = v ?? true;
            _recalcular();
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(
              value: true,
              label: 'Atualizar preço e categoria',
            ),
            DropdownMenuEntry(value: false, label: 'Manter o que existe'),
          ],
        ),
      if (_oQue == OQue.lista) ...[
        DropdownMenu<String?>(
          label: const Text('Loja para linhas sem supermercado'),
          width: 300,
          initialSelection: _lojaSemSupermercado,
          onSelected: (v) {
            _lojaSemSupermercado = v;
            _recalcular();
          },
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: null, label: 'Nenhuma'),
            for (final l in lojas)
              DropdownMenuEntry(value: l.id, label: l.nome),
          ],
        ),
        DropdownMenu<bool>(
          label: const Text('Artigos sem quantidade'),
          width: 300,
          initialSelection: _incluirSemQuantidade,
          onSelected: (v) {
            _incluirSemQuantidade = v ?? false;
            _recalcular();
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: false, label: 'Ignorar'),
            DropdownMenuEntry(value: true, label: 'Importar para o catálogo'),
          ],
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Cópia completa (JSON)
  // ---------------------------------------------------------------------------

  Future<void> _importarJson(String nome, Uint8List bytes) async {
    setState(() {
      _ocupado = true;
      _estado = 'A ler o ficheiro…';
      _resultado = null;
    });
    try {
      final seed = SeedFicheiro.lerTexto(utf8.decode(bytes));
      final dados = ref.read(dadosRepositoryProvider);
      var substituir = false;
      if (await dados.temDados()) {
        if (!mounted) return;
        substituir = await _confirmarSubstituir() ?? false;
        if (!substituir) {
          setState(() => _estado = 'Importação cancelada.');
          return;
        }
      }
      setState(
        () => _estado =
            'A importar ${seed.compras.length} compras e '
            '${seed.artigos.length} artigos…',
      );
      final resultado = await ImportadorSeed(dados: dados)
          .importar(seed, substituir: substituir);
      // A cache local volta a puxar tudo o que o servidor tem agora.
      await ref.read(syncRepositoryProvider).recarregarTudo();
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _versaoResumo++;
        _estado = null;
      });
    } on SeedInvalido catch (e) {
      if (!mounted) return;
      setState(() => _estado = null);
      await _mostrarErros(e.erros);
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = null);
      _mostrar('A importação falhou e nada foi alterado: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool?> _confirmarSubstituir() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Substituir dados atuais?'),
      content: const Text(
        'Esta conta já tem dados. Se continuares, são apagados e substituídos '
        'pelos do ficheiro. Nada é duplicado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Substituir'),
        ),
      ],
    ),
  );

  Future<void> _mostrarErros(List<String> erros) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ficheiro inválido'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: Text(erros.join('\n'))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Exportar
  // ---------------------------------------------------------------------------

  Future<Uint8List> _letraPdf() async =>
      (await rootBundle.load('assets/fonts/InstrumentSans.ttf')).buffer
          .asUint8List();

  Future<void> _exportar() async {
    setState(() {
      _ocupado = true;
      _estado = 'A preparar o ficheiro…';
    });
    final hoje = DateTime.now();
    final formato = _formatoExportar;
    final nome =
        'cabaz-${_oQueExportar.slug}-${dataIso(hoje)}.${formato.extensao}';
    final lojas = ref.read(lojasProvider).value ?? const <Loja>[];
    final categorias =
        ref.read(categoriasProvider).value ?? const <Categoria>[];
    final artigos = ref.read(artigosProvider).value ?? const <Artigo>[];
    final precos = ref.read(precosAtuaisProvider).value ?? const <PrecoAtual>[];
    final itens = ref.read(itensListaProvider).value ?? const <ItemLista>[];
    try {
      final List<int> bytes;
      switch (_oQueExportar) {
        case OQue.taloes:
          return; // Os talões só se importam (não estão no menu Exportar).
        case OQue.copia:
          final tabelas = await ref.read(dadosRepositoryProvider).lerTudo();
          bytes = utf8.encode(exportacaoParaTexto(montarExportacao(tabelas)));
        case OQue.compras:
          final tabelas = await ref.read(dadosRepositoryProvider).lerTudo();
          final t = tabelasCompras(
            tabelas,
            desde: _periodo.desde(hoje),
            lojaId: _lojaExportar,
          );
          bytes = formato == Formato.csv
              ? escreverCsv(t.first)
              : escreverXlsx(t);
        case OQue.artigos:
          if (formato == Formato.pdf) {
            bytes = await pdfTabela(
              titulo: 'Tabela de preços · ${formatarData(hoje)}',
              tabela: tabelaPrecos(
                artigos: artigos,
                lojas: lojas,
                precos: precos,
                lojaId: _lojaExportar,
              ),
              letra: await _letraPdf(),
            );
          } else {
            final t = tabelaArtigos(
              artigos: artigos,
              categorias: categorias,
              lojas: lojas,
              precos: precos,
              lojaId: _lojaExportar,
            );
            bytes = formato == Formato.csv ? escreverCsv(t) : escreverXlsx([t]);
          }
        case OQue.lista:
          if (formato == Formato.pdf || formato == Formato.txt) {
            final loja = lojas.where((l) => l.id == _lojaExportar).firstOrNull;
            final linhas = _linhasDaLista(itens, artigos, categorias, lojas);
            if (formato == Formato.txt) {
              bytes = utf8.encode(
                textoLista(linhas, loja: loja?.nome, data: hoje),
              );
            } else {
              bytes = await pdfLista(
                titulo: tituloLista(loja: loja?.nome, data: hoje),
                blocos: blocosLista(linhas, mostrarLoja: loja == null),
                letra: await _letraPdf(),
              );
            }
          } else {
            final t = tabelaLista(
              itens: itens,
              artigos: artigos,
              categorias: categorias,
              lojas: lojas,
              lojaId: _lojaExportar,
            );
            bytes = formato == Formato.csv ? escreverCsv(t) : escreverXlsx([t]);
          }
      }
      await guardarBytes(nome, bytes);
    } catch (e) {
      if (mounted) _mostrar('Não foi possível exportar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _estado = null;
        });
      }
    }
  }

  /// Lista do mês para TXT/PDF: incluídos e ainda por comprar.
  List<LinhaParaTexto> _linhasDaLista(
    List<ItemLista> itens,
    List<Artigo> artigos,
    List<Categoria> categorias,
    List<Loja> lojas,
  ) {
    final artigo = {for (final a in artigos) a.id: a};
    final categoria = {for (final c in categorias) c.id: c};
    final loja = {for (final l in lojas) l.id: l};
    return [
      for (final i in itens)
        if (i.incluido &&
            !i.comprado &&
            artigo.containsKey(i.artigoId) &&
            loja.containsKey(i.lojaId) &&
            (_lojaExportar == null || i.lojaId == _lojaExportar))
          LinhaParaTexto(
            loja: loja[i.lojaId]!.nome,
            categoria: categoria[artigo[i.artigoId]!.categoriaId],
            artigo: artigo[i.artigoId]!.nome,
            quantidade: formatarQtd(i.qtd, artigo[i.artigoId]!.unidade),
          ),
    ];
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // O catálogo das importações vem destes providers: ouvi-los mantém-nos
    // ativos e com valor (ver providersDoCatalogo).
    for (final p in providersDoCatalogo) {
      ref.watch(p);
    }
    final tema = Theme.of(context);
    final online = ref.watch(estadoSyncProvider).value?.online ?? true;
    final largo = MediaQuery.sizeOf(context).width >= larguraEcraLargo;
    final lojas = [
      for (final l in ref.watch(lojasProvider).value ?? const <Loja>[])
        if (!l.arquivada) l,
    ];
    final previa = _previa;

    return Pagina(
      titulo: 'Importar e exportar',
      corpo: ConteudoCentrado(
        largura: 1100,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResumoDadosCard(key: ValueKey(_versaoResumo)),
            const SizedBox(height: 16),
            ZonaLargar(
              aoLargar: (nome, bytes) => _ocupado ? null : _abrir(nome, bytes),
              aoLargarVarios: _largar,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Importar dados', style: tema.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          DropdownMenu<OQue>(
                            label: const Text('O que importar'),
                            width: 260,
                            initialSelection: _oQue,
                            onSelected: (v) {
                              if (v == null || v == _oQue) return;
                              _cancelarPrevia();
                              setState(() => _oQue = v);
                            },
                            dropdownMenuEntries: [
                              for (final o in OQue.values)
                                DropdownMenuEntry(value: o, label: o.rotulo),
                            ],
                          ),
                          DropdownMenu<Formato>(
                            key: ValueKey('formato-imp-$_oQue'),
                            label: const Text('Formato'),
                            width: 200,
                            initialSelection: _oQue.paraImportar.first,
                            dropdownMenuEntries: [
                              for (final f in _oQue.paraImportar)
                                DropdownMenuEntry(value: f, label: f.rotulo),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _ocupado || (_oQue == OQue.copia && !online)
                                ? null
                                : _escolherFicheiro,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Escolher ficheiro'),
                          ),
                          if (largo)
                            Text(
                              'ou larga aqui o ficheiro',
                              style: TextStyle(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (_oQue == OQue.copia && !online)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Sem rede: a importação grava no servidor numa só '
                            'transação. Liga a rede para importar.',
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                        ),
                      if (_semExistentes &&
                          _oQue == OQue.compras &&
                          previa != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Sem ligação ao servidor: não foi possível saber que '
                            'compras já existem.',
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_estado != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_ocupado) ...[
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(_estado!)),
                ],
              ),
            ],
            if (previa != null && _tabela != null) ...[
              const SizedBox(height: 16),
              PrevisualizacaoCard(
                nomeFicheiro: _nome!,
                tabela: _tabela!,
                tipo: _oQue.tipo!,
                campos: _campos,
                previa: previa,
                aoMudarCampo: (i, c) {
                  _campos = [..._campos]..[i] = c;
                  _recalcular();
                },
                opcoes: _opcoesDoTipo(),
                online: online && !_semExistentes,
                aGravar: _ocupado,
                aoImportar: _gravarLote,
                aoCancelar: _cancelarPrevia,
              ),
            ],
            if (_taloes != null) ...[
              const SizedBox(height: 16),
              PrevisualizacaoTaloes(
                taloes: _taloes!,
                naoReconhecidos: _naoReconhecidos,
                escolhas: _escolhas,
                nomesArtigos: {
                  for (final a
                      in ref.watch(artigosProvider).value ?? const <Artigo>[])
                    a.id: a.nome,
                },
                online: online,
                aGravar: _ocupado,
                aoImportar: _gravarTaloes,
                aoCancelar: _cancelarPrevia,
              ),
            ],
            if (_resultado != null) ...[
              const SizedBox(height: 16),
              ResumoImportacao(resultado: _resultado!),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exportar', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DropdownMenu<OQue>(
                          label: const Text('O que exportar'),
                          width: 260,
                          initialSelection: _oQueExportar,
                          onSelected: (v) => setState(() {
                            _oQueExportar = v ?? _oQueExportar;
                            _formatoExportar = _oQueExportar.paraExportar.first;
                          }),
                          dropdownMenuEntries: [
                            for (final o in OQue.values)
                              if (o.paraExportar.isNotEmpty)
                                DropdownMenuEntry(value: o, label: o.rotulo),
                          ],
                        ),
                        if (_oQueExportar == OQue.compras)
                          DropdownMenu<Periodo>(
                            label: const Text('Período'),
                            width: 220,
                            initialSelection: _periodo,
                            onSelected: (v) =>
                                setState(() => _periodo = v ?? _periodo),
                            dropdownMenuEntries: [
                              for (final p in Periodo.values)
                                DropdownMenuEntry(value: p, label: p.rotulo),
                            ],
                          ),
                        if (_oQueExportar != OQue.copia)
                          DropdownMenu<String?>(
                            label: const Text('Loja'),
                            width: 220,
                            initialSelection: _lojaExportar,
                            onSelected: (v) =>
                                setState(() => _lojaExportar = v),
                            dropdownMenuEntries: [
                              const DropdownMenuEntry(
                                value: null,
                                label: 'Todas',
                              ),
                              for (final l in lojas)
                                DropdownMenuEntry(value: l.id, label: l.nome),
                            ],
                          ),
                        DropdownMenu<Formato>(
                          key: ValueKey('formato-exp-$_oQueExportar'),
                          label: const Text('Formato'),
                          width: 200,
                          initialSelection: _formatoExportar,
                          onSelected: (v) => setState(
                            () => _formatoExportar = v ?? _formatoExportar,
                          ),
                          dropdownMenuEntries: [
                            for (final f in _oQueExportar.paraExportar)
                              DropdownMenuEntry(value: f, label: f.rotulo),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _exportar,
                      icon: const Icon(Icons.download),
                      label: const Text('Exportar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumoImportacao extends StatelessWidget {
  const ResumoImportacao({super.key, required this.resultado});

  final ResultadoImportacao resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = resultado;
    Widget marca(bool? ok) => switch (ok) {
      true => Icon(Icons.check_circle, color: Colors.green.shade700),
      false => Icon(Icons.cancel, color: tema.colorScheme.error),
      null => const Icon(Icons.remove),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                marca(r.tudoOk),
                const SizedBox(width: 8),
                Text(
                  r.tudoOk
                      ? 'Importação concluída'
                      : 'Importação com diferenças',
                  style: tema.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Numero('Compras', formatarInteiro(r.contagens['compras'])),
                _Numero('Artigos', formatarInteiro(r.contagens['artigos'])),
                _Numero('Lojas', formatarInteiro(r.contagens['lojas'])),
                _Numero('Total', formatarCent(r.totalCent)),
                _Numero('Para rever', formatarInteiro(r.comprasRever)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            for (final l in r.lojas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: marca(l.ok),
                title: Text(l.nome),
                subtitle: Text(
                  '${l.nCompras} ${l.nCompras == 1 ? 'compra' : 'compras'}'
                  '${l.ok == false ? ' · esperado ${formatarCent(l.esperadoCent!)}' : ''}',
                ),
                trailing: Text(formatarCent(l.totalCent)),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: marca(r.totalOk),
              title: const Text('Total global'),
              subtitle: r.totalOk == false
                  ? Text('esperado ${formatarCent(r.totalEsperadoCent!)}')
                  : null,
              trailing: Text(
                formatarCent(r.totalCent),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: tema.textTheme.labelMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(valor, style: tema.textTheme.headlineSmall),
      ],
    );
  }
}

/// Números atuais no servidor, para verificar a sincronização.
/// Atualiza sozinho de 20 em 20 segundos enquanto está visível.
class ResumoDadosCard extends ConsumerStatefulWidget {
  const ResumoDadosCard({super.key});

  @override
  ConsumerState<ResumoDadosCard> createState() => _ResumoDadosCardState();
}

class _ResumoDadosCardState extends ConsumerState<ResumoDadosCard> {
  ResumoDados? _resumo;
  bool _semRede = false;
  bool _aCarregar = false;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    _relogio = Timer.periodic(const Duration(seconds: 20), (_) => _carregar());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_aCarregar) return;
    setState(() => _aCarregar = true);
    try {
      final r = await ref.read(dadosRepositoryProvider).resumoDados();
      if (mounted) {
        setState(() {
          _resumo = r;
          _semRede = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _semRede = true);
    } finally {
      if (mounted) setState(() => _aCarregar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = _resumo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumo dos dados',
                    style: tema.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: _aCarregar ? null : _carregar,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_semRede)
              Text(
                r == null
                    ? 'Sem rede: não foi possível ler os números do servidor.'
                    : 'Sem rede: números da última leitura.',
                style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
              ),
            if (r == null && !_semRede)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (r != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _Numero('Compras', formatarInteiro(r.nCompras)),
                  _Numero('Artigos', formatarInteiro(r.nArtigos)),
                  _Numero('Lojas', formatarInteiro(r.lojas.length)),
                  _Numero('Total', formatarCent(r.totalCent)),
                ],
              ),
              const SizedBox(height: 8),
              for (final l in r.lojas)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.nome),
                  subtitle: Text(
                    '${l.nCompras} ${l.nCompras == 1 ? 'compra' : 'compras'}',
                  ),
                  trailing: Text(formatarCent(l.totalCent)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
