# Notas · fora do âmbito

- `dart format --set-exit-if-changed .` falha no Windows depois de um build Android: não consegue listar um caminho longo dentro de `build/`. Contorno: `dart format --set-exit-if-changed lib test` (ou apagar `build/`).
- Orçamento (Fase 4) fora da cópia JSON e da importação: `orcamentos` não entra em `SupabaseDadosRepository.tabelas` nem em `importar_lote`. Acrescentar se a cópia tiver de restaurar tudo.
- Dados: há uma categoria com um nome estragado, "Frutas e legumes⇥k⇥Lidl⇥1,50" (linha de ficheiro importada com tabulações). Corrigir ou apagar em Artigos → Categorias (vista a 2026-10-27).
- Talões (Fase 5): o leitor do E.Leclerc foi feito com 1 só exemplo (variantes, como descontos, ficam como "a rever"); no cabeçalho com letras espaçadas só uma localidade de uma palavra fica certa. Se for preciso distinguir as compras vindas de talão, `origem 'talao'` obriga a mudar a RPC `importar_lote` (decisão D6 da Fase 5).
