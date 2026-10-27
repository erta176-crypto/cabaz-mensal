/// Secção do talão → nome da categoria da app, para sugerir a categoria dos
/// artigos novos. Escrito a partir das secções dos talões reais (Pingo Doce
/// e E.Leclerc) e das categorias em uso; só vale se a categoria existir.
library;

import '../../domain/texto.dart';

const _mapa = {
  'peixaria': 'Peixe',
  'talho': 'Carne e charcutaria',
  'padaria/pastelaria': 'Padaria e pastelaria',
  'frutas e vegetais': 'Frutas e legumes',
  'queijos': 'Lacticínios e ovos',
  'produtos lacteos': 'Lacticínios e ovos',
  'ovos': 'Lacticínios e ovos',
  'congelados': 'Gelados e congelados',
  'deterg. e prod. limpeza': 'Limpeza e casa',
  'd.p.h': 'Limpeza e casa',
  'produtos pessoais': 'Higiene e beleza',
  'bebidas': 'Bebidas e infusões',
  'mercearia': 'Mercearia',
  'mercearia + pet food': 'Mercearia',
  'bazar': 'Outros (roupa, ferramentas, plantas…)',
  'bazar ligeiro permanente': 'Outros (roupa, ferramentas, plantas…)',
};

/// Nome da categoria sugerida para uma secção, ou null.
String? categoriaDaSeccao(String? seccao) =>
    seccao == null ? null : _mapa[normalizar(seccao).trim()];
