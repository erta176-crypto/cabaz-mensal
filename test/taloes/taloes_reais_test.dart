// Verificação com os talões reais de dados-privados/talões/ (fora do git).
// Sem essa pasta (ex.: no GitHub) o teste é saltado. Só mostra contagens:
// nenhum texto de talão real sai daqui.
import 'dart:io';

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
}
