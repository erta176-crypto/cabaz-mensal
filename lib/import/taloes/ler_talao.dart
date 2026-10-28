/// Reconhece a loja de um talão e lê-o.
library;

import 'leclerc.dart';
import 'lidl.dart';
import 'mercadona.dart';
import 'pingo_doce.dart';
import 'talao.dart';

/// null se nenhuma loja reconhece o texto. Lança [FormatException] se a
/// loja é conhecida mas o talão está incompleto.
TalaoLido? lerTalao(String texto) =>
    lerPingoDoce(texto) ??
    lerLidl(texto) ??
    lerLeclerc(texto) ??
    lerMercadona(texto);
