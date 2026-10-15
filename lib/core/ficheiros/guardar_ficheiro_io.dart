import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// No telemóvel, abre a folha de partilha (guardar em Ficheiros, Drive, email…).
Future<void> guardarTexto(String nome, String conteudo) async {
  final ficheiro = XFile.fromData(
    utf8.encode(conteudo),
    mimeType: 'application/json',
    name: nome,
  );
  await SharePlus.instance.share(
    ShareParams(files: [ficheiro], fileNameOverrides: [nome], subject: nome),
  );
}
