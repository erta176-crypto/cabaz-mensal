// Verificação com os talões reais de dados-privados/talões/ (fora do git).
// Sem essa pasta (ex.: no GitHub) o teste é saltado. Só mostra contagens:
// nenhum texto de talão real sai daqui.
import 'dart:io';

import 'package:cabaz_mensal/domain/modelos.dart';
import 'package:cabaz_mensal/import/previsualizacao.dart';
import 'package:cabaz_mensal/import/taloes/importar_taloes.dart';
import 'package:cabaz_mensal/import/taloes/leclerc.dart';
import 'package:cabaz_mensal/import/taloes/lidl.dart';
import 'package:cabaz_mensal/import/taloes/pingo_doce.dart';
import 'package:cabaz_mensal/import/taloes/talao.dart';
import 'package:cabaz_mensal/import/taloes/texto_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

final _pasta = Directory('dados-privados/talões');

void main() {
  setUpAll(() {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp
        .createTempSync('pdfrx')
        .path;
  });

  Future<void> verificar(
    String subpasta,
    TalaoLido? Function(String) ler,
  ) async {
    final pdfs = Directory('${_pasta.path}/$subpasta')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    var batem = 0;
    final falhas = <String>[];
    for (final f in pdfs) {
      final t = ler(await textoDoPdf(f.readAsBytesSync()));
      if (t != null && t.bate && t.naoReconhecidas.isEmpty) {
        batem++;
      } else {
        falhas.add(f.uri.pathSegments.last);
      }
    }
    // ignore: avoid_print
    print('$subpasta: $batem/${pdfs.length} batem');
    expect(falhas, isEmpty, reason: 'Não batem: ${falhas.length}');
  }

  final saltar = !_pasta.existsSync() ? 'sem dados-privados/talões' : false;
  for (final (subpasta, ler) in [
    ('Faturas Pingo Doce', lerPingoDoce),
    ('Lidl_', lerLidl),
    ('E.Leclerc', lerLeclerc),
  ]) {
    test(
      '$subpasta: todos os talões reais batem',
      () => verificar(subpasta, ler),
      skip: saltar,
    );
  }

  test('análise: o pago das linhas soma o total e nenhuma linha é negativa', () async {
    final lidos = <({String ficheiro, String texto})>[
      for (final f in _pasta.listSync(recursive: true).whereType<File>())
        if (f.path.toLowerCase().endsWith('.pdf'))
          (
            ficheiro: f.uri.pathSegments.last,
            texto: await textoDoPdf(f.readAsBytesSync()),
          ),
    ];
    final r = analisarTaloes(
      lidos,
      Catalogo(
        lojas: const [
          Loja(id: 'pd', slug: 'pingo-doce', nome: 'Pingo Doce'),
          Loja(id: 'lidl', slug: 'lidl', nome: 'Lidl'),
          Loja(id: 'lec', slug: 'e-leclerc', nome: 'E.Leclerc'),
        ],
        categorias: const [],
        artigos: const [],
      ),
      const [],
    );
    var certos = 0;
    for (final t in r.taloes) {
      final pago = t.linhas.fold(0, (s, l) => s + l.pagoCent);
      if (pago == t.talao.totalCent && t.linhas.every((l) => l.pagoCent >= 0)) {
        certos++;
      }
    }
    // ignore: avoid_print
    print(
      'análise: $certos/${r.taloes.length} certos; '
      '${r.taloes.where((t) => t.estado == EstadoTalao.repetidoNoLote).length} '
      'repetidos no lote; ${r.naoReconhecidos.length} não reconhecidos',
    );
    expect(r.naoReconhecidos, isEmpty);
    expect(certos, r.taloes.length);
  }, skip: saltar);
}
