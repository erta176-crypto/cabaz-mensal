import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'tipo_ficheiro.dart';

/// Na web, descarrega o ficheiro diretamente.
Future<void> guardarBytes(String nome, List<int> bytes) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: tipoDe(nome)),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..style.display = 'none';
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

Future<void> guardarTexto(String nome, String conteudo) =>
    guardarBytes(nome, utf8.encode(conteudo));

/// Na web, descarrega um .txt. Devolve true (ficheiro descarregado).
Future<bool> partilharTexto(String nome, String texto) async {
  await guardarTexto('$nome.txt', texto);
  return true;
}
