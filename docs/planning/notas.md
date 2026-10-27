# Notas · fora do âmbito

- `dart format --set-exit-if-changed .` falha no Windows depois de um build Android: não consegue listar um caminho longo dentro de `build/`. Contorno: `dart format --set-exit-if-changed lib test` (ou apagar `build/`).
- Cor da loja convertida em dois sítios com regras diferentes: `corDeHex` (`lib/features/artigos/artigos_page.dart`, aceita sem `#`) e `corDaLoja` (`lib/features/estatisticas/cores.dart`, exige `#rrggbb`, Fase 2). Unificar numa só.
- Painel e Histórico: quando a rede volta, o erro "sem rede" fica no ecrã até tocar em "Tentar outra vez". Poderiam voltar a pedir sozinhos ao detetar a rede (`estadoSyncProvider`). Visto no portão da Fase 2.
- Orçamento (Fase 4) fora da cópia JSON e da importação: `orcamentos` não entra em `SupabaseDadosRepository.tabelas` nem em `importar_lote`. Acrescentar se a cópia tiver de restaurar tudo.
- **Pedido do utilizador (2026-10-27), para quando for oportuno:** no ecrã de entrada, botão para ver a palavra-passe; e entrar com PIN e com dados biométricos (impressão digital / rosto). Precisa de plano próprio (pacote `local_auth`, guardar a sessão de forma segura, comportamento na web).
- Dados: há uma categoria com um nome estragado, "Frutas e legumes⇥k⇥Lidl⇥1,50" (linha de ficheiro importada com tabulações). Corrigir ou apagar em Artigos → Categorias (vista a 2026-10-27).
- Talões (Fase 5): o leitor do E.Leclerc foi feito com 1 só exemplo (variantes, como descontos, ficam como "a rever"); no cabeçalho com letras espaçadas só uma localidade de uma palavra fica certa. Se for preciso distinguir as compras vindas de talão, `origem 'talao'` obriga a mudar a RPC `importar_lote` (decisão D6 da Fase 5).
