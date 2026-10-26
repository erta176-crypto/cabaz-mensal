# Notas · fora do âmbito

- `dart format --set-exit-if-changed .` falha no Windows depois de um build Android: não consegue listar um caminho longo dentro de `build/`. Contorno: `dart format --set-exit-if-changed lib test` (ou apagar `build/`).
- Cor da loja convertida em dois sítios com regras diferentes: `corDeHex` (`lib/features/artigos/artigos_page.dart`, aceita sem `#`) e `corDaLoja` (`lib/features/estatisticas/cores.dart`, exige `#rrggbb`, Fase 2). Unificar numa só.
- Painel e Histórico: quando a rede volta, o erro "sem rede" fica no ecrã até tocar em "Tentar outra vez". Poderiam voltar a pedir sozinhos ao detetar a rede (`estadoSyncProvider`). Visto no portão da Fase 2.
- Orçamento (Fase 4) fora da cópia JSON e da importação: `orcamentos` não entra em `SupabaseDadosRepository.tabelas` nem em `importar_lote`. Acrescentar se a cópia tiver de restaurar tudo.
