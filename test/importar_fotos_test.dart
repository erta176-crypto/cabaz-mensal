import 'dart:io';

import 'package:cabaz_mensal/core/tema.dart';
import 'package:cabaz_mensal/data/providers.dart';
import 'package:cabaz_mensal/data/repositorios.dart';
import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/features/importar_exportar/importar_exportar_page.dart';
import 'package:cabaz_mensal/import/taloes/linhas_ocr.dart';
import 'package:flutter/foundation.dart';
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
  @override
  Future<List<({String lojaId, String data, String? local, int totalCent})>>
  comprasExistentes() async => const [];

  @override
  Future<ResumoDados> resumoDados() async =>
      const ResumoDados(nCompras: 0, nArtigos: 0, lojas: []);

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

  /// Uma fotografia temporária, como as que o image_picker copia.
  XFile foto(String nome, {String pasta = 'a'}) {
    final f = File('${cache.path}/cache/$pasta/$nome')
      ..createSync(recursive: true);
    return XFile(f.path, name: nome);
  }

  Future<void> abrir(
    WidgetTester t, {
    List<XFile> galeria = const [],
    List<XFile> perdidas = const [],
  }) async {
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
          dadosRepositoryProvider.overrideWithValue(_Dados()),
          artigosRepositoryProvider.overrideWithValue(_Artigos()),
          categoriasRepositoryProvider.overrideWithValue(_Categorias()),
          seletorFotosProvider.overrideWithValue((
            camera: () async => const [],
            galeria: () async => galeria,
            perdidas: () async => perdidas,
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
  }

  Future<void> escolherFotografia(WidgetTester t) async {
    await t.tap(find.byType(DropdownMenu<OQue>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Talões (fotografia)').last);
    await t.pumpAndSettle();
  }

  testWidgets('no Android: "Talões (fotografia)" com câmara e galeria', (
    t,
  ) async {
    await abrir(t);
    await escolherFotografia(t);
    expect(find.text('Tirar fotografia'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
    expect(find.text('Escolher ficheiro'), findsNothing);
  });

  for (final outro in [TargetPlatform.iOS, TargetPlatform.windows]) {
    testWidgets('em ${outro.name} não há talões por fotografia', (t) async {
      debugDefaultTargetPlatformOverride = outro;
      try {
        await abrir(t);
        await t.tap(find.byType(DropdownMenu<OQue>).first);
        await t.pumpAndSettle();
        expect(find.text('Talões (PDF)'), findsWidgets);
        expect(find.text('Talões (fotografia)'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('duas fotografias com o mesmo nome dão dois talões, com '
      '"Ver fotografia"', (t) async {
    await abrir(
      t,
      galeria: [
        foto('talao.jpg'),
        foto('talao.jpg', pasta: 'b'),
      ],
    );
    await escolherFotografia(t);
    await t.tap(find.text('Escolher da galeria'));
    await t.pumpAndSettle();
    expect(find.text('Talões (fotografia)'), findsWidgets);
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.textContaining(RegExp(r'· Novo$')), findsOneWidget);
    expect(find.textContaining('Repetido neste lote'), findsOneWidget);
    // O repetido aparece fechado: abri-lo mostra a sua fotografia.
    expect(find.text('Ver fotografia'), findsOneWidget);
    await t.tap(find.textContaining('Repetido neste lote'));
    await t.pumpAndSettle();
    expect(find.text('Ver fotografia'), findsNWidgets(2));
  });

  testWidgets('fotografia recuperada (app terminada com a câmara aberta) '
      'é lida ao abrir', (t) async {
    await abrir(t, perdidas: [foto('camera.jpg')]);
    expect(find.text('Tirar fotografia'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.textContaining(RegExp(r'· Novo$')), findsOneWidget);
  });

  testWidgets('cancelar limpa e apaga a cópia temporária', (t) async {
    final f = foto('talao.jpg');
    await abrir(t, galeria: [f]);
    await escolherFotografia(t);
    await t.tap(find.text('Escolher da galeria'));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(File(f.path).existsSync(), isFalse);
  });
}
