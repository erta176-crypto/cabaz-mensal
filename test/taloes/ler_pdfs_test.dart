import 'dart:typed_data';

import 'package:cabaz_mensal/import/taloes/ler_pdfs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê os PDFs pela ordem; os ilegíveis ficam à parte', () async {
    final progresso = <(int, int)>[];
    final r = await lerPdfs(
      [
        (nome: 'a.pdf', bytes: Uint8List.fromList([1])),
        (nome: 'b.pdf', bytes: Uint8List.fromList([2])),
        (nome: 'c.pdf', bytes: Uint8List.fromList([3])),
      ],
      (bytes) async => bytes.first == 2
          ? throw const FormatException('PDF ilegível')
          : 'texto ${bytes.first}',
      progresso: (feitos, total) => progresso.add((feitos, total)),
    );
    expect(r.lidos.map((l) => (l.ficheiro, l.texto)), [
      ('a.pdf', 'texto 1'),
      ('c.pdf', 'texto 3'),
    ]);
    expect(r.ilegiveis.single.ficheiro, 'b.pdf');
    expect(r.ilegiveis.single.motivo, 'PDF ilegível');
    expect(progresso, [(0, 3), (1, 3), (2, 3)]);
  });
}
