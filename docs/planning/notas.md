# Notas · fora do âmbito

- `dart format --set-exit-if-changed .` falha no Windows depois de um build Android: não consegue listar um caminho longo dentro de `build/`. Contorno: `dart format --set-exit-if-changed lib test` (ou apagar `build/`).
- Cor da loja convertida em dois sítios com regras diferentes: `corDeHex` (`lib/features/artigos/artigos_page.dart`, aceita sem `#`) e `corDaLoja` (`lib/features/estatisticas/cores.dart`, exige `#rrggbb`, Fase 2). Unificar numa só.
