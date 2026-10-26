# Fase 4 · Orçamento mensal

**Estado:** plano escrito a 2026-10-26, **à espera de aprovação**. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Executar tarefa a tarefa (T1 → T6). O que não está aqui não se faz: vai para `docs/planning/notas.md`.

Fases seguintes, já decididas (planos próprios quando lá chegarmos): **Fase 5** talões em PDF (Lidl, Pingo Doce, E.Leclerc; web e Android; pré-visualizar e confirmar antes de gravar), **Fase 6** talões por fotografia (OCR, só Android).

---

## 0. Contexto e decisões (fechadas, não reabrir)

### O que existe hoje
- Tabelas sincronizadas (`tabelasSync` em `lib/data/local/base_local.dart`): escritas na cache + fila (`Escrita`), receção por `atualizado_em`. Chave local = `id`, salvo nas tabelas com chave natural (`itens_lista`, `aliases`, `preferencias`).
- Padrão de tabela do servidor: `user_id default auth.uid()`, trigger `set_atualizado_em`, RLS `<tabela>_select/insert/update/delete_dono` com `(select auth.uid()) = user_id`, índice `(user_id, atualizado_em)`, `apagado_em` para eliminar.
- `public.apagar_todos_dados()` (última versão em `20261015120000_fase1a.sql`) apaga as tabelas do utilizador e marca `preferencias.reiniciado_em`.
- O Painel com "Este mês" já tem o gasto total e por categoria do mês (`painelProvider`, com cache sem rede). A Lista mostra "Estimado" e "No carrinho" no rodapé.
- O pacote `uuid` (já no projeto) gera UUID v5.

### Decisões tomadas com o utilizador (2026-10-26)
| # | Decisão |
|---|---|
| D1 | **Orçamento por mês**: valor total do mês e, opcionalmente, valores por categoria. |
| D2 | **Cópia do mês anterior**: se o mês atual não tem orçamento e o anterior tem, o Painel mostra "Copiar o orçamento de <mês>" (um toque). Não se copia sozinho (um orçamento apagado de propósito não volta). |
| D3 | **Painel**: com o período "Este mês", cartão "Orçamento" (gasto vs orçamento, total e por categoria, barras e avisos a 80% e 100%) e menu ⋮ → "Editar orçamento". |
| D4 | **Lista**: no rodapé, se o mês tiver orçamento total, "Orçamento: faltam X" e quanto fica depois da lista (`faltam − estimado`); em `colorScheme.error` quando passa. |
| D5 | **Sincronizado** entre aparelhos (tabela nova no Supabase). |
| D6 | **Id determinístico**: `id = uuid v5(namespace, '<user_id>|<aaaa-mm>|<categoria_id ou total>')`. Dois aparelhos sem rede que criam o mesmo orçamento geram o mesmo id: o upsert por `id` junta-os, sem caso especial na sincronização. O índice único no servidor é a segunda proteção. |

### Regras
- Dinheiro em cêntimos inteiros. Só `lib/data/` fala com o Supabase e o drift. Repositório abstrato.
- Menus em vez de chips, ações no ⋮, cores do `colorScheme`.
- Antes de editar um ficheiro partilhado (`supabase/migrations/`, `lib/data/local/base_local.dart`, `lib/data/repositorios.dart`, `lib/data/providers.dart`, `lib/domain/`), dizer o impacto segundo o graphify numa linha. Para a base de dados, completar com `rg` pelo nome da tabela/função no Dart.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada, commit pequeno.
- Sem pacotes novos.

### Fora do âmbito
Orçamento por loja; avisos fora da app (notificações); incluir o orçamento na cópia JSON e na importação (fica em `notas.md`); orçamento de meses passados no Histórico.

---

## T1 · Migração `supabase/migrations/20261027000000_fase4_orcamentos.sql` [ ]

```sql
-- Cabaz Mensal · Fase 4 · orçamento mensal (total e por categoria)

create table public.orcamentos (
  -- Id determinístico, calculado no cliente (uuid v5 de user, mês e categoria).
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mes date not null check (extract(day from mes) = 1),
  -- null = orçamento total do mês.
  categoria_id uuid references public.categorias (id) on delete cascade,
  valor_cent integer not null check (valor_cent >= 0),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz,
  constraint orcamentos_unico unique nulls not distinct (user_id, mes, categoria_id)
);

create trigger set_atualizado_em before update on public.orcamentos
  for each row execute function public.set_atualizado_em();

alter table public.orcamentos enable row level security;

create policy orcamentos_select_dono on public.orcamentos for select to authenticated
  using ((select auth.uid()) = user_id);
create policy orcamentos_insert_dono on public.orcamentos for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy orcamentos_update_dono on public.orcamentos for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy orcamentos_delete_dono on public.orcamentos for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.orcamentos from anon;

create index on public.orcamentos (user_id, atualizado_em);
create index on public.orcamentos (categoria_id);

-- Apagar todos os dados passa a apagar também os orçamentos
-- (mesmo corpo de 20261015120000_fase1a.sql + orcamentos).
create or replace function public.apagar_todos_dados() ... ;
```
(O corpo de `apagar_todos_dados` copia-se da última versão e acrescenta `delete from public.orcamentos where user_id = uid;` antes de `categorias`. Confirmar antes que nenhuma migração posterior a redefiniu.)

Depois: o utilizador aplica no SQL Editor; verificar com `list_tables` (colunas, RLS ativo), um `insert` + `select` numa transação com `rollback` simulando o utilizador (incluindo duas linhas com `categoria_id` null no mesmo mês → a segunda falha por `orcamentos_unico`), `get_advisors` sem avisos novos (os "unused index" novos contam como esperados).

---

## T2 · Domínio: `lib/domain/orcamento.dart` [ ]

Funções puras, testes primeiro (`test/orcamento_test.dart`).

```dart
class Orcamento {
  const Orcamento({required this.id, required this.mes, this.categoriaId, required this.valorCent});
  final String id; final DateTime mes; /// dia 1
  final String? categoriaId; /// null = total
  final int valorCent;
  factory Orcamento.fromMap(Map<String, dynamic> m);
  Map<String, dynamic> toMap(); // id, mes (aaaa-mm-dd), categoria_id, valor_cent
}

/// Id determinístico (uuid v5) de um orçamento.
String idOrcamento(String userId, DateTime mes, String? categoriaId);

/// Estado de um gasto face ao orçamento.
enum NivelOrcamento { ok, quase, passou } // < 80 %, 80–100 %, > 100 %
NivelOrcamento nivel(int gastoCent, int orcamentoCent);

/// Linha do cartão: orçamento, gasto, quanto falta (negativo = passou).
typedef LinhaOrcamento = ({String? categoriaId, int orcamentoCent, int gastoCent, int faltaCent, NivelOrcamento nivel});

/// Junta os orçamentos do mês com o gasto do Painel (total e por categoria).
/// Categorias com gasto mas sem orçamento não entram.
({LinhaOrcamento? total, List<LinhaOrcamento> categorias}) compararOrcamento(
    List<Orcamento> doMes, DadosPainel gasto);
```
Testes: `idOrcamento` igual para os mesmos dados e diferente para mês ou categoria diferentes; é um UUID válido; `nivel` nas fronteiras (79 %, 80 %, 100 %, 101 %; orçamento 0); `compararOrcamento` com total e 2 categorias (uma sem gasto); `fromMap`/`toMap` ida e volta.

---

## T3 · Dados: sincronização e repositório [ ]

- `lib/data/local/base_local.dart`: `'orcamentos'` em `tabelasSync` (depois de `categorias`). Chave = `id` (caminho por omissão; nada a mudar em `chaveDe`/`onConflictDe`/`filtroDe`/`enviaId`).
- `lib/data/sync/servidor_supabase.dart` e o `ServidorFalso` dos testes: confirmar que tratam uma tabela nova sem código extra (se houver lista de tabelas, acrescentar).
- `lib/data/repositorios.dart`: `abstract interface class OrcamentosRepository { Stream<List<Orcamento>> observar(); Future<void> definir(DateTime mes, String? categoriaId, int? valorCent); Future<void> copiar(DateTime de, DateTime para); }` — `definir` com `null` apaga (marca `apagado_em`); `copiar` cria no mês `para` as linhas do mês `de` (ids novos, determinísticos).
- `lib/data/local/repositorios_locais.dart`: `LocalOrcamentosRepository(base, escrita, utilizadorId)`, com `Escrita.inserir`/`apagar` (como os outros repositórios locais).
- `lib/data/providers.dart`: `orcamentosRepositoryProvider`, `orcamentosProvider` (stream).

Testes (`test/sync/` com `Dispositivo` e `ServidorFalso`): definir sem rede e sincronizar cria a linha no servidor; dois dispositivos sem rede definem o total do mesmo mês → uma só linha, vence o último; apagar e voltar a definir reativa a mesma linha; `copiar` copia total e categorias; `limparCache` e `apagar_todos_dados` (via `reiniciado_em`) limpam.

---

## T4 · Painel: cartão "Orçamento" [ ]

Em `lib/features/painel/painel_page.dart`, só com `Periodo.esteMes` (com ou sem loja: o orçamento é do mês inteiro; com loja escolhida, o cartão não aparece):
- Depois dos 4 números. Título "Orçamento" e ⋮ → "Editar orçamento".
- Sem orçamento no mês: texto "Sem orçamento para <mês>." e botões "Definir orçamento" e, se o mês anterior tiver, "Copiar de <mês anterior>".
- Com orçamento: linha do total (gasto / orçamento, barra `LinearProgressIndicator` com cor por nível: `primary` ok, `tertiary` quase, `error` passou, e texto "faltam X" ou "passou X") e uma linha por categoria com orçamento (nome, barra, valores). O nível também em texto (não só cor).
- Diálogo "Editar orçamento": campo "Total do mês (€)" e uma linha por categoria (campo opcional), valores com `centDeTexto` (`lib/domain/dinheiro.dart`); campo vazio = sem orçamento; guardar chama `definir` só para o que mudou.

Testes (`test/painel_orcamento_test.dart`): sem orçamento mostra os botões; "Copiar de setembro" chama `copiar`; com orçamento mostra "faltam"/"passou" e o nível certo; com outro período o cartão não aparece; diálogo grava total e categoria e ignora campos vazios.

---

## T5 · Lista: rodapé com o orçamento [ ]

Em `lib/features/lista/lista_page.dart`, no rodapé, por baixo de "Estimado · No carrinho", se o mês atual tiver orçamento total: "Orçamento: faltam X · depois da lista Y" (`Y = faltam − estimado`). Gasto do mês = `painelProvider((periodo: esteMes, lojaId: null))` (com cache sem rede); sem dados do painel, a linha não aparece. "passou" em `colorScheme.error`.

Testes (`test/lista_test.dart`, acrescentar): com orçamento e gasto mostra a linha certa; sem orçamento não mostra; estimado maior do que o que falta → "depois da lista" negativo em `error`.

---

## T6 · Documentação e fecho [ ]
- `docs/architecture/mapa.md` (tabela, domínio, repositório, ecrãs), `sincronizacao.md` (tabela nova, id determinístico), `docs/decisions/0009-orcamento-id-deterministico.md` (D6), `ESTADO.md`, marcar T1–T6.
- `notas.md`: orçamento fora da cópia JSON e da importação.

## Portão da Fase 4
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. Migração aplicada e verificada (T1), advisors sem avisos novos.
3. Definir o orçamento no telemóvel aparece no PC (e vice-versa); sem rede, define-se e envia-se depois.
4. Painel "Este mês": valores do cartão batem com o gasto do mês (SQL de controlo) e com o orçamento definido; avisos a 80 % e 100 %.
5. Lista: "faltam" e "depois da lista" certos.
6. Verificação visual em claro e escuro, < e > 800 px, web e Android.
7. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Fase 4: migração da tabela orcamentos`
2. `Domínio do orçamento: id determinístico e comparação com o gasto`
3. `Dados: orçamentos sincronizados`
4. `Painel: cartão do orçamento`
5. `Lista: orçamento no rodapé`
6. `docs: Fase 4`
