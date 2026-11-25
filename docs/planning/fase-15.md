# Fase 15 · Eliminar um talão no Histórico

**Estado:** aprovado (2026-11-25); T1 feita. Uma migração (coluna `apagado_em` em `compras`; funções e vista passam a respeitá-la); sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** no Histórico, eliminar um talão (uma compra) com confirmação e "Anular". Depois de eliminado, desaparece do Histórico, do Painel (totais, barras, orçamento, folha da Fase 14), do resumo por loja, das exportações e da cópia JSON, neste e nos outros aparelhos. "Anular" repõe tudo.

Origem: prompt do utilizador de 2026-11-25 (o seu "P1"). Aprovado pelo utilizador a 2026-11-25: opção A (só com rede; as compras continuam só no servidor) e os preços (`registos_preco`) que vieram do talão ficam.

## 0. O que existe (confirmado no código e no servidor, 2026-11-25)
- `compras` e `linhas_compra` só existem no servidor (não estão em `tabelasSync`); sem `apagado_em`. RLS por dono com `select`, `insert`, `update` e `delete`; trigger `set_atualizado_em` nas duas. `linhas_compra.compra_id` → `compras` `on delete cascade`.
- Leem compras no servidor: vista `resumo_por_loja` (fase1a, `security_invoker`), RPCs `painel`, `historico_compras` (fase2) e `artigos_do_painel` (fase14). Escrevem: `concluir_compra`, `importar_lote` (`on conflict (id) do nothing`), `importar_seed`, `apagar_todos_dados`.
- Leem compras no cliente (`supabase_repositorios.dart`): `contarCompras`, `comprasDaLoja`, `locaisUsados`, `temDados`, `comprasExistentes` (talões repetidos na importação) e `lerTudo` (cópia JSON e exportações, via `montarExportacao`). As linhas de uma compra: `linhasCompraProvider`.
- `SupabaseDadosRepository` não tem testes (usa o `SupabaseClient` diretamente); `montarExportacao` é uma função pura com testes (`exportar_loja_eliminada_test.dart`).
- As compras importadas têm id novo (`r.novoId()`): reimportar um talão cria uma compra nova.
- Histórico: `_comprasHistoricoProvider` (`historico_page.dart:27`), `_linhaCompra` sem "⋮", seleção `_selecionada` no ecrã largo; `DetalheCompraPage` (`detalhe_compra.dart`). Painel: `painelProvider` (com cache `painel:%`).
- `registos_preco` não tem `compra_id`. Dados: ~160 compras, um utilizador.

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Só `compras` ganha `apagado_em timestamptz`. As linhas seguem a compra: todas as leituras de linhas passam pela compra (RPCs com `join`; `linhasCompraProvider` só abre compras visíveis; `lerTudo` filtra no cliente, D3). Sem índice novo: com ~160 compras o `compras_user_id_idx` chega, e um índice parcial ficaria como "unused index" nos advisors; rever se o volume crescer. |
| D2 | Servidor (uma migração, numa transação, assinaturas iguais): `painel`, `historico_compras`, `artigos_do_painel` e `resumo_por_loja` com `apagado_em is null`. `concluir_compra`, `importar_lote`, `importar_seed` e `apagar_todos_dados` não mudam (inserem compras novas ou apagam tudo). |
| D3 | Cliente: `contarCompras`, `comprasDaLoja`, `locaisUsados`, `temDados` e `comprasExistentes` pedem só compras sem `apagado_em` (um talão eliminado pode ser importado de novo sem "Repetido"). `lerTudo` lê `apagado_em` e uma função pura, `semComprasEliminadas`, retira as compras eliminadas e as suas linhas antes da cópia JSON e das exportações. |
| D4 | Eliminar grava logo: `DadosRepository.eliminarCompra(id)` (`apagado_em = now()`). "Anular" (aviso de 5 s) chama `reporCompra(id)` (`apagado_em = null`). É um "soft delete" verdadeiro: sobrevive a fechar a app, e o servidor é a única verdade. Sem rede: o talão fica e aparece "Sem rede: liga-te para eliminar o talão." (ou "…para repor o talão."). |
| D5 | UI: "⋮" (tooltip "Ações do talão") em cada talão da lista e no detalhe, com "Eliminar talão"; diálogo com loja, data e total. Depois de eliminar ou repor: `invalidate` do `_comprasHistoricoProvider` e de todo o `painelProvider` (todas as famílias). No ecrã largo, eliminar o talão selecionado limpa a seleção; no detalhe (ecrã estreito), fecha o detalhe e o aviso aparece no Histórico. |
| D6 | Os `registos_preco` do talão ficam (decisão do utilizador): o preço atual e a evolução do preço continuam a contar com eles; reimportar o mesmo talão cria registos repetidos para a mesma data. Registado em `notas.md`. |
| D7 | Fora do âmbito, para `notas.md`: ecrã "Talões eliminados" para repor depois dos 5 s (hoje: reimportar o PDF); compras de origem "lista" (`concluir_compra`) eliminadas não mexem na Lista do mês. |
| D8 | Implantação: a migração vem primeiro. Com a coluna `null` em todas as compras, as funções novas devolvem o mesmo que as antigas, e o APK e a web antigos continuam a funcionar. O APK novo só depois da migração; a web só muda com o push, depois do portão. |

## T1 · Migração e verificação no servidor [x] (2026-11-25)
- Escritos (2026-11-25): `supabase/migrations/20261126000000_fase15_eliminar_compra.sql` e `supabase/verificacao/fase15.sql`. As definições ativas no servidor eram iguais às das migrações fase2, fase1a e fase14; a migração só lhes junta o filtro (confirmado por diff). Os `create or replace` mantêm as permissões.
- Antes de aplicar: `fase15.sql` sem as referências a `apagado_em` deu 0 diferentes (painel e historico_compras em 10 filtros; resumo_por_loja em 4 lojas).
- Aplicada pelo utilizador (2026-11-25). Confirmado: coluna `apagado_em` (nula), filtro nas 3 funções e na vista, `security_invoker` mantido, permissões iguais (`anon` não, `authenticated` sim). `fase15.sql`: 0 diferentes (painel e historico_compras em 10 filtros, resumo_por_loja em 4 lojas), 0 compras eliminadas. `fase14.sql`: 128 barras, 0 diferentes. `get_advisors`: nenhum aviso novo (só o da Leaked Password Protection e o INFO do índice de `lojas`, já existentes).
- `supabase/migrations/20261126000000_fase15_eliminar_compra.sql`: `begin`/`commit`; `alter table compras add column apagado_em timestamptz`; `create or replace` das 3 funções e da vista (D2), copiadas das versões atuais com o filtro a mais. Em comentário, "Como desfazer" (repor as definições da fase2, fase1a e fase14; a coluna pode ficar). Aplicada pelo utilizador no SQL Editor; depois `get_advisors` sem avisos novos.
- `supabase/verificacao/fase15.sql`, só leitura (não grava nada): para o utilizador, conta as compras eliminadas e compara cada leitura com uma contagem direta nas tabelas, só com `apagado_em is null`: total e n.º de compras do `painel` ("este mês" e "tudo", sem e com cada loja), `historico_compras` (n.º e soma), `resumo_por_loja` (por loja). Tem de dar 0 diferentes. Corre também `fase14.sql`.
- Correr os dois logo depois de aplicar (0 eliminadas: prova que nada mudou) e outra vez no portão, depois de eliminar um talão (prova que fica de fora).

## T2 · Repositório [ ]
- Primeiro os testes (puros): `semComprasEliminadas` retira as compras com `apagado_em` e só as suas linhas, e deixa o resto igual; a cópia JSON (`montarExportacao`) sai sem elas; `comprasExistentes` ignora as eliminadas (o mapeamento passa a ser uma função pura testada).
- `DadosRepository.eliminarCompra` e `reporCompra` (`repositorios.dart`, `supabase_repositorios.dart`, falsos em `test/fakes.dart` e nos outros que implementam a interface); filtros de D3. Ficheiros partilhados: impacto pelo grafo antes de editar.
- Os pedidos finos ao PostgREST (`update`, `.isFilter('apagado_em', null)` nas contagens) não têm teste unitário (o repositório não tem onde os injetar); ficam provados no portão (reimportar, contagens da loja) e no `fase15.sql`.

## T3 · UI no Histórico [ ]
- `historico_page.dart` e `detalhe_compra.dart`: "⋮" → "Eliminar talão" → diálogo → `eliminarCompra` → aviso "Talão eliminado." com "Anular" (`reporCompra`) → `invalidate` (D5).
- Testes de widget (repositório falso): o diálogo mostra loja, data e total; "Cancelar" não chama nada; confirmar chama `eliminarCompra` e o talão sai da lista; "Anular" chama `reporCompra` e o talão volta; sem rede mostra a mensagem e o talão fica; ecrã largo limpa a seleção; no detalhe, eliminar fecha o detalhe e mostra o aviso; o Painel volta a pedir os dados.

## T4 · Documentação [ ]
- `mapa.md` (migração, `fase15.sql`, `semComprasEliminadas`), `sincronizacao.md` (compras: eliminadas com `apagado_em`, só com rede, fora da fila), `notas.md` (D6 e D7; retirar a nota da Fase 14 sobre esta fase), `ESTADO.md`, este plano.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes; `flutter build web` compila; `get_advisors` sem avisos novos.
- No telemóvel (`adb install -r`), com um talão de teste (ex.: o PDF do Mercadona, que se pode reimportar):
  1. Eliminar e "Anular": o talão volta.
  2. Eliminar e deixar o aviso fechar: sai do Histórico; o total do Painel, a barra da loja e o cartão do orçamento baixam exatamente o valor do talão; na folha da loja (Fase 14) a soma continua igual à barra.
  3. `fase15.sql` e `fase14.sql`: 0 diferentes, com 1 compra eliminada.
  4. Na web (outro aparelho), depois de atualizar, também desapareceu.
  5. Reimportar o mesmo PDF: aparece como novo (não "Repetido") e os totais voltam.
  6. Sem rede: eliminar mostra a mensagem e o talão fica.
