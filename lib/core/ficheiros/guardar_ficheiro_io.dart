import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'tipo_ficheiro.dart';

/// No telemóvel, abre a folha de partilha (guardar em Ficheiros, Drive, email…).
Future<void> guardarBytes(String nome, List<int> bytes) =>
    SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            mimeType: tipoDe(nome),
            name: nome,
          ),
        ],
        fileNameOverrides: [nome],
        subject: nome,
      ),
    );

Future<void> guardarTexto(String nome, String conteudo) =>
    guardarBytes(nome, utf8.encode(conteudo));

/// No telemóvel, partilha o texto (WhatsApp, notas, email…).
/// Devolve false: não foi descarregado nenhum ficheiro.
Future<bool> partilharTexto(String nome, String texto) async {
  await SharePlus.instance.share(ShareParams(text: texto, subject: nome));
  return false;
}
