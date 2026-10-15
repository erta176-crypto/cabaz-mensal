import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Na web, descarrega o ficheiro diretamente.
Future<void> guardarTexto(String nome, String conteudo) async {
  final bytes = utf8.encode(conteudo);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
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

/// Na web, descarrega um .txt. Devolve true (ficheiro descarregado).
Future<bool> partilharTexto(String nome, String texto) async {
  await guardarTexto('$nome.txt', texto);
  return true;
}
