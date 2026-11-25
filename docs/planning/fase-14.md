# Fase 14 · Painel: tocar numa loja ou categoria mostra os artigos

**Estado:** aprovado (2026-11-25); T1 e T2 feitas. Uma migração (função SQL nova, só leitura, sem tabelas nem índices novos); sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** no Painel, tocar numa barra de "Por loja" ou "Por categoria" (incluindo "Sem categoria" e "Outras") abre a lista dos artigos que dão esse valor, com o mesmo período e a mesma loja do Painel. A soma da lista é sempre igual ao valor da barra.

Origem: prompt do utilizador de 2026-11-25 (o seu "P3"). Eliminar talão fica para a Fase 15.

## 0. O que existe (confirmado)
- RPC `painel(p_de, p_ate, p_loja)` (`supabase/migrations/20261026000000_fase2.sql:7`): "por loja" soma `compras.total_cent`; "por categoria" e "artigos" somam `linhas_compra.pago_cent` (com `artigos.categoria_id`). `security invoker`, filtra `user_id = auth.uid()`.
- `painel_page.dart`: filtros Período e Loja (`FiltroCompras`); "Por loja" só sem loja escolhida; "Por categoria" com as 8 maiores e "Outras" (`categoriasTopo`, `estatisticas.dart:193`); "Artigos com mais gasto" já abre `DialogoVerArtigo`.
- `BarrasHorizontais` (`barras_horizontais.dart`) não tem toque.
- Sem rede, o Painel mostra a última resposta guardada (`painel:%`) com um aviso (`_avisoCache`, `painel_page.dart:130`). As linhas das compras só existem no servidor.
- Índices que a função usa já existem: `compras_user_id_idx`, `compras_loja_id_data_idx`, `linhas_compra_compra_id_idx` (consulta a `pg_indexes`, 2026-11-25).
- Servidor, 2026-11-25: em todas as compras a soma das linhas é igual a `total_cent` e todas as linhas têm artigo (consulta só com contagens). A lista tem de bater mesmo quando isto falhar (D3).

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | RPC nova `artigos_do_painel(p_de, p_ate, p_loja, p_categorias uuid[], p_sem_categoria boolean)`: só leitura, `security invoker`, `search_path = ''`, `user_id = auth.uid()` como o `painel`, só para `authenticated`. Por artigo: total (`sum(pago_cent)`), quantidade (`sum(quantidade)`, `sum(peso_g)`) e n.º de compras (`count(distinct compra_id)`), por ordem do total. |
| D2 | Mesmo filtro do Painel. Loja tocada = essa loja. Categoria tocada = essa categoria (e a loja do filtro, se houver). "Sem categoria" = `p_sem_categoria`. "Outras" = a lista das categorias fora das 8 maiores (`p_categorias`), porque já vêm na resposta do `painel`. |
| D3 | A soma bate sempre. A RPC devolve também, à parte: o valor das linhas sem artigo e, na vista por loja, a diferença entre `total_cent` das compras e a soma das suas linhas (compras sem linhas ou que não batem). A folha mostra estas linhas só quando ≠ 0. |
| D4 | A soma é feita no servidor numa só consulta, com as mesmas regras do `painel` (as duas funções na mesma migração ficam lado a lado no SQL de verificação). Na Fase 15, ao juntar `apagado_em` às compras, as duas funções mudam juntas (nota no plano da 15). |
| D5 | Folha inferior que rola: título "Mercadona · Este mês", uma linha por artigo (nome, "3 un" ou "1,25 kg" pela unidade do artigo, n.º de compras, total), total no fim. Tocar num artigo abre o `DialogoVerArtigo`. No ecrã largo, a folha fica com a largura máxima da Material (não ocupa o ecrã todo). |
| D6 | Só com rede, como as linhas de uma compra. Sem rede: "Sem rede: liga-te para ver os artigos." Se o Painel está a mostrar a cache, as barras continuam a abrir a folha (com dados atuais) e a folha avisa: "O Painel está desatualizado; esta lista é de agora." |

## T1 · Migração e verificação no servidor [x] (2026-11-25)
- Escritos: `supabase/migrations/20261125000000_fase14_artigos_do_painel.sql` e `supabase/verificacao/fase14.sql`.
- Antes de aplicar (2026-11-25), com uma cópia da função em `pg_temp` numa transação sem commit: 128 barras ("este mês" e "tudo", sem e com loja: 7 de loja, 114 de categoria, 7 de "Outras"), 0 diferentes. Não havia barras "Sem categoria".
- Aplicada pelo utilizador (2026-11-25). Confirmado em `pg_proc`: `security invoker`, `search_path` vazio, sem `execute` para `anon`, com `execute` para `authenticated`. `fase14.sql` com as RPCs reais: 128 barras, 0 diferentes. `get_advisors`: segurança só com o aviso antigo (Leaked Password Protection); desempenho só com um INFO antigo (índice `lojas_user_id_atualizado_em_idx` por usar). Nenhum aviso novo.
- `supabase/migrations/20261125000000_fase14_artigos_do_painel.sql`: só `create function` + `revoke`/`grant`. Aplicada pelo utilizador no SQL Editor (decisão 0002); depois `get_advisors` sem avisos novos.
- Antes de aplicar: correr o corpo da função como consulta de leitura com a sessão do utilizador (`set_config('request.jwt.claims', …, true)` numa transação) e comparar com o `painel`. Depois de aplicar: o mesmo, chamando as duas RPCs. Casos: 2 lojas e 2 categorias reais, "Sem categoria", "Outras", períodos "Este mês" e "Tudo", com e sem loja no filtro. Mostrar só totais e contagens (sem nomes de artigos).
- O SQL de verificação fica em `supabase/verificacao/fase14.sql` (só leitura), para voltar a correr na Fase 15.

## T2 · Modelo, repositório e provider [x] (2026-11-25)
- Feito: `ArtigoDetalhe`, `DetalhePainel` e `BarraPainel` (chave do provider, com igualdade por valor: um record com `List` compararia a lista pela identidade e o provider voltaria a pedir em cada reconstrução) em `domain/estatisticas.dart`; `artigosDoPainel` na interface e em `supabase_estatisticas.dart` (mensagem de D6 sem rede); `detalhePainelProvider`. Esboços nas 5 classes falsas de teste.
- Testes: `test/detalhe_painel_test.dart` (3) e grupo `artigosDoPainel` em `estatisticas_repositorio_test.dart` (5).
- Primeiro os testes: `DetalhePainel.fromJson`; `totalCent` = artigos + sem artigo + diferença; ordem pelo total; quantidade em un e em kg; parâmetros enviados à RPC para loja, categoria, "Sem categoria" e "Outras".
- `DetalhePainel` (`domain/estatisticas.dart`), `EstatisticasRepository.artigosDoPainel` (`repositorios.dart`, `supabase_estatisticas.dart`), `detalhePainelProvider` (`providers.dart`, com `refazerQuandoVoltarARede`). Ficheiros partilhados: impacto pelo grafo antes de editar.

## T3 · UI: toque nas barras e folha dos artigos [ ]
- `BarrasHorizontais`: `aoTocar` opcional por item; com toque, a linha tem `InkWell`, semântica de botão com o rótulo e o valor, e altura ≥ 48 px.
- `painel_page.dart`: toque em loja, categoria, "Sem categoria" e "Outras" abre a folha de D5.
- Testes de widget: a folha abre com o título, os artigos por ordem do total e o total igual ao da barra; linhas de D3 só quando ≠ 0; tocar num artigo abre o `DialogoVerArtigo`; sem rede mostra a mensagem de D6; Painel da cache mostra o aviso de D6; as barras sem `aoTocar` ficam como estão (Lista, Orçamento).

## T4 · Documentação [ ]
- `mapa.md` (função SQL, `supabase/verificacao/`, folha nova), `ESTADO.md`, este plano; nota em `docs/planning/notas.md` para a Fase 15 (D4).

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes; `flutter build web` compila; `get_advisors` sem avisos novos; `supabase/verificacao/fase14.sql` sem diferenças.
- No telemóvel (`adb install -r`): tocar em "Mercadona" e em "Limpeza e casa" (períodos "Este mês" e "Tudo"); a soma da folha é igual à barra; tocar num artigo abre o detalhe; sem rede aparece a mensagem.
- Na web (`flutter run -d chrome`): o mesmo toque, abaixo e acima de 800 px, em claro e escuro.
