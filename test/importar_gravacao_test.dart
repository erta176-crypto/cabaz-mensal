import 'dart:io';

import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/importar_exportar/importar_exportar_page.dart';
import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';

final _mercadona = File('test/fixtures/taloes/mercadona.txt')
    .readAsStringSync()
    .replaceAll('\r\n', '\n');

/// Uma caixa por linha, como se o OCR tivesse lido a linha inteira.
List<CaixaOcr> _caixas(String texto) => [
  for (final (i, l) in texto.split('\n').indexed)
    if (l.trim().isNotEmpty)
      CaixaOcr(
        texto: l.trim(),
        esquerda: 10,
        cima: i * 40.0,
        direita: 600,
        baixo: i * 40.0 + 30,
      ),
];

class _Dados implements DadosRepository {
  _Dados(this.aoImportarLote);
  final Future<Map<String, int>> Function() aoImportarLote;

  @override
  Future<Map<String, int>> importarLote(Map<String, dynamic> payload) =>
      aoImportarLote();

  @override
  Future<List<({String lojaId, String data, String? local, int totalCent})>>
  comprasExistentes() async => const [];

  @override
  Future<ResumoDados> resumoDados() async =>
      const ResumoDados(nCompras: 0, nArtigos: 0, lojas: []);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Sync implements SyncRepository {
  _Sync({this.falha = false});
  final bool falha;

  @override
  Future<void> recarregarTudo({bool descartarPendentes = false}) async {
    if (falha) throw Exception('sem rede');
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Artigos implements ArtigosRepository {
  @override
  Future<List<Artigo>> apagados() async => const [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Categorias implements CategoriasRepository {
  @override
  Future<List<Categoria>> apagadas() async => const [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  late Directory cache;
  setUp(() {
    cache = Directory.systemTemp.createTempSync('cabaz');
    Directory('${cache.path}/cache').createSync();
  });
  tearDown(() => cache.deleteSync(recursive: true));

  Future<void> abrirComTalao(
    WidgetTester t, {
    required Future<Map<String, int>> Function() importarLote,
    bool recarregarFalha = false,
  }) async {
    final f = File('${cache.path}/cache/a/talao.jpg')
      ..createSync(recursive: true);
    t.view.physicalSize = const Size(1000, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          lojasProvider.overrideWith(
            (_) => Stream.value(const [
              Loja(id: 'm', slug: 'mercadona', nome: 'Mercadona'),
            ]),
          ),
          categoriasProvider.overrideWith((_) => Stream.value(const [])),
          artigosProvider.overrideWith((_) => Stream.value(const [])),
          aliasesProvider.overrideWith((_) => Stream.value(const {})),
          precosAtuaisProvider.overrideWith((_) => Stream.value(const [])),
          itensListaProvider.overrideWith((_) => Stream.value(const [])),
          estadoSyncProvider.overrideWith(
            (_) => Stream.value(const EstadoSync()),
          ),
          dadosRepositoryProvider.overrideWithValue(_Dados(importarLote)),
          syncRepositoryProvider.overrideWithValue(
            _Sync(falha: recarregarFalha),
          ),
          artigosRepositoryProvider.overrideWithValue(_Artigos()),
          categoriasRepositoryProvider.overrideWithValue(_Categorias()),
          seletorFotosProvider.overrideWithValue((
            camera: () async => const [],
            galeria: () async => [XFile(f.path, name: 'talao.jpg')],
            perdidas: () async => const [],
          )),
          ocrFotosProvider.overrideWithValue((
            inteira: (_) async => _caixas(_mercadona),
            emFaixas: (_) async => const [],
          )),
        ],
        child: MaterialApp(
          theme: construirTema(Brightness.light, fontesGoogle: false),
          home: const ImportarExportarPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownMenu<OQue>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Talões (fotografia)').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Escolher da galeria'));
    await t.pumpAndSettle();
    await t.tap(find.text('Importar 1 talão'));
    await t.pumpAndSettle();
  }

  testWidgets('RPC com êxito e recarregar a falhar: "gravados" e prévia '
      'fechada', (t) async {
    await abrirComTalao(
      t,
      importarLote: () async => {'compras': 1},
      recarregarFalha: true,
    );
    expect(find.textContaining('Os dados foram gravados'), findsOneWidget);
    expect(find.textContaining('nada foi alterado'), findsNothing);
    expect(find.text('Importar 1 talão'), findsNothing);
  });

  testWidgets('ErroSemResposta: mensagem do servidor e prévia fechada', (
    t,
  ) async {
    await abrirComTalao(
      t,
      importarLote: () async => throw const ErroSemResposta(),
    );
    expect(find.textContaining('não respondeu a tempo'), findsOneWidget);
    expect(find.text('Importar 1 talão'), findsNothing);
  });

  testWidgets('ErroDados: "nada foi alterado" e prévia aberta', (t) async {
    await abrirComTalao(
      t,
      importarLote: () async => throw const ErroDados('Erro na base de dados'),
    );
    expect(find.textContaining('nada foi alterado'), findsOneWidget);
    expect(find.text('Importar 1 talão'), findsOneWidget);
  });
}
