# Fase 2 · Painel, estatísticas e histórico

**Estado:** plano escrito e aprovado a 2026-10-25. Aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Este plano é para ser executado tarefa a tarefa (T1 → T9), por esta ordem. Cada tarefa diz os ficheiros, o código a escrever (assinaturas exatas), os testes e o critério de "feito". O que não está aqui não se faz: vai para `docs/planning/notas.md`.

---

## 0. Contexto e decisões (fechadas, não reabrir)

### O que existe hoje
- Os destinos `/painel` e `/historico` já estão no shell (`lib/features/shell/shell.dart`, `destinos`) e no router (`lib/core/router.dart`), mas mostram `EmBrevePage`.
- **Cache local (drift):** só guarda `preferencias`, `lojas`, `categorias`, `artigos`, `aliases`, `itens_lista` e `registos_preco` (`tabelasSync` em `lib/data/local/base_local.dart`). **`compras` e `linhas_compra` não estão na cache:** lêem-se do Supabase, com rede, como faz `SupabaseConsultasCompras` (`lib/data/supabase/supabase_repositorios.dart`).
- A tabela `estado` do drift (chave/valor) guarda pequenos valores: `BaseLocal.lerEstado(chave)` e `gravarEstado(chave, valor)`. `limparCache()` (chamada quando `preferencias.reiniciado_em` muda) apaga as chaves `cursor:%`; `limparTudo()` (sair da conta) apaga tudo.
- `compras`: `id, user_id, loja_id, local, data, total_cent, poupanca_cent, origem ('manual','talao','importacao','lista'), ficheiro, rever, criado_em, atualizado_em`. **Não tem `apagado_em`.**
- `linhas_compra`: `id, user_id, compra_id, artigo_id (pode ser null), texto_original, quantidade, peso_g, preco_unit_cent, bruto_cent, desconto_cent, pago_cent, …`. **Não guarda a ordem do talão.**
- `lojas.cor` é texto `#rrggbb` (pode ser null).
- Já existem `formatarCent`, `formatarData`, `formatarInteiro` (`lib/core/formatos.dart`), `normalizar` (`lib/domain/texto.dart`), `ErroDados` e `comErrosTraduzidos` (`lib/data/repositorios.dart`, `lib/data/supabase/base.dart`), `Pagina` (`lib/features/shell/shell.dart`), `estadoSyncProvider` (online/offline).
- `DialogoVerArtigo` está em `lib/features/lista/dialogos_lista.dart` e só abre a partir da Lista.

### Decisões tomadas com o utilizador (2026-10-25)
| # | Decisão |
|---|---|
| D1 | Gráficos com **`fl_chart` fixado em `1.2.0`** (MIT, Android e web, só depende de `equatable` e `vector_math`, já no `pubspec.lock`). A 1.3.0 saiu a 2026-10-21, demasiado recente. Ver `docs/decisions/0006-fl-chart.md`. |
| D2 | **Painel sem rede mostra o último resultado guardado** (cache na tabela `estado`), com o aviso "Dados de <data e hora>; sem rede". Ver `docs/decisions/0007-painel-com-cache.md`. |
| D3 | **Histórico só consulta:** lista, filtros, pesquisa e detalhe. Não se editam nem apagam compras. Sem rede, mostra "Sem rede: o histórico precisa do servidor." (as compras não estão na cache). |
| D4 | **Evolução do preço de um artigo fica no "Ver artigo"**, com dados de `registos_preco` (cache local, funciona sem rede). O "Ver artigo" passa a abrir também a partir de Artigos (menu ⋮ → "Ver"). |
| D5 | Totais do painel calculados **no servidor** com uma RPC (`public.painel`); a pesquisa do histórico também (`public.historico_compras`). |

### Regras que valem para todas as tarefas
- Dinheiro sempre em **cêntimos inteiros** (`int`). Só se converte para `double` no último passo, para desenhar o gráfico (`cent / 100`). Nunca se somam `double`.
- Só `lib/data/` fala com o Supabase e com o drift. Os ecrãs usam providers.
- Repositórios abstratos em `lib/data/repositorios.dart`, implementação em `lib/data/supabase/`.
- UI: **menus (DropdownButtonFormField) em vez de chips**, ações no menu **⋮**, cores do `Theme.of(context).colorScheme` (nada de cores fixas nos ecrãs, exceto a cor da loja).
- Acessibilidade: cada gráfico tem `Semantics(label: …)` com os valores em texto e o desenho dentro de `ExcludeSemantics`; áreas de toque ≥ 48 px.
- Pacote novo: **só `fl_chart: 1.2.0`**. Antes de usar uma classe do `fl_chart`, confirmar a API na fonte do pacote (MCP Dart `read_package_uris` / `rip_grep_packages`, ou `~/.pub-cache`). Não inventar parâmetros.
- Antes de editar um ficheiro partilhado (`pubspec.yaml`, `lib/core/router.dart`, `lib/data/repositorios.dart`, `lib/data/providers.dart`, `lib/data/local/base_local.dart`, `lib/domain/`, `supabase/migrations/`), dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com: `dart format --set-exit-if-changed lib test`, `flutter analyze` (sem avisos), `flutter test --reporter compact`, `graphify update .`, marcar a tarefa aqui com `[x]`, commit pequeno.

### Fora do âmbito (não fazer)
Editar ou apagar compras; marcar compras como revistas; orçamento; avisos de preço; exportar a partir do painel; guardar compras na cache local; mudar a sincronização; comparação de preços online.

---

## T1 · Migração `supabase/migrations/20261026000000_fase2.sql` [x]

Criar o ficheiro com **exatamente** este conteúdo:

```sql
-- Cabaz Mensal · Fase 2 · painel e histórico (só leitura; não altera dados)

-- ---------------------------------------------------------------------------
-- RPC painel: totais de um período, opcionalmente de uma loja.
-- Por categoria e por artigo soma as linhas (pago_cent); o total soma as compras.
-- ---------------------------------------------------------------------------
create or replace function public.painel(p_de date, p_ate date, p_loja uuid default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with c as (
    select id, loja_id, data, total_cent, poupanca_cent
    from public.compras
    where user_id = auth.uid()
      and data between p_de and p_ate
      and (p_loja is null or loja_id = p_loja)
  ),
  l as (
    select lc.artigo_id, lc.pago_cent, a.categoria_id
    from public.linhas_compra lc
    join c on c.id = lc.compra_id
    left join public.artigos a on a.id = lc.artigo_id
  )
  select jsonb_build_object(
    'total_cent', (select coalesce(sum(total_cent), 0) from c),
    'n_compras', (select count(*) from c),
    'poupanca_cent', (select coalesce(sum(poupanca_cent), 0) from c),
    'por_mes', coalesce((
      select jsonb_agg(jsonb_build_object('mes', to_char(m, 'YYYY-MM'), 'total_cent', t, 'n_compras', n) order by m)
      from (select date_trunc('month', data)::date as m, sum(total_cent) as t, count(*) as n
            from c group by 1) x), '[]'::jsonb),
    'por_loja', coalesce((
      select jsonb_agg(jsonb_build_object('loja_id', loja_id, 'total_cent', t, 'n_compras', n) order by t desc)
      from (select loja_id, sum(total_cent) as t, count(*) as n from c group by 1) x), '[]'::jsonb),
    'por_categoria', coalesce((
      select jsonb_agg(jsonb_build_object('categoria_id', categoria_id, 'total_cent', t) order by t desc)
      from (select categoria_id, sum(pago_cent) as t from l group by 1) x), '[]'::jsonb),
    'artigos', coalesce((
      select jsonb_agg(jsonb_build_object('artigo_id', artigo_id, 'total_cent', t, 'n_linhas', n) order by t desc)
      from (select artigo_id, sum(pago_cent) as t, count(*) as n
            from l where artigo_id is not null
            group by 1 order by 2 desc limit 10) x), '[]'::jsonb)
  );
$$;

revoke execute on function public.painel(date, date, uuid) from public, anon;
grant execute on function public.painel(date, date, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC historico_compras: compras de um período, opcionalmente de uma loja,
-- e só as que têm uma linha com um dos artigos ou com o texto no talão.
-- p_artigos vem da app (pesquisa sem acentos no catálogo local).
-- ---------------------------------------------------------------------------
create or replace function public.historico_compras(
  p_de date,
  p_ate date,
  p_loja uuid default null,
  p_artigos uuid[] default null,
  p_texto text default null
)
returns table (
  id uuid, loja_id uuid, data date, local text, total_cent integer,
  poupanca_cent integer, origem text, rever boolean, n_linhas integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.id, c.loja_id, c.data, c.local, c.total_cent, c.poupanca_cent, c.origem, c.rever,
         (select count(*)::integer from public.linhas_compra lc where lc.compra_id = c.id)
  from public.compras c
  where c.user_id = auth.uid()
    and c.data between p_de and p_ate
    and (p_loja is null or c.loja_id = p_loja)
    and (
      (p_artigos is null and p_texto is null)
      or exists (
        select 1 from public.linhas_compra lc
        where lc.compra_id = c.id
          and (lc.artigo_id = any (coalesce(p_artigos, '{}'))
               or (p_texto is not null and strpos(lower(coalesce(lc.texto_original, '')), lower(p_texto)) > 0))
      )
    )
  order by c.data desc, c.criado_em desc;
$$;

revoke execute on function public.historico_compras(date, date, uuid, uuid[], text) from public, anon;
grant execute on function public.historico_compras(date, date, uuid, uuid[], text) to authenticated;
```

Depois:
1. O utilizador aplica a migração no SQL Editor (o `apply_migration` é recusado).
2. Verificar com o MCP Supabase (`execute_sql`), simulando o utilizador numa transação que acaba em `rollback`:
   ```sql
   begin;
   select set_config('request.jwt.claims', json_build_object('sub', (select user_id from public.compras limit 1), 'role', 'authenticated')::text, true);
   set local role authenticated;
   select public.painel('2000-01-01', '2100-01-01');
   select count(*) from public.historico_compras('2000-01-01', '2100-01-01');
   rollback;
   ```
   - `painel(...)->>'total_cent'` tem de ser igual a `select sum(total_cent) from public.compras`; `n_compras` igual a `count(*)`; a soma de `por_mes[*].total_cent` igual ao total.
   - `historico_compras` sem filtros devolve tantas linhas como `count(*)` de `compras`.
   - Sem o `set_config` (sem utilizador), `painel` devolve `total_cent = 0`.
3. `get_advisors` (security e performance): sem avisos novos (os "unused index" já existentes não contam).

**Feito quando:** os três pontos acima estão confirmados e registados aqui em uma linha (sem valores reais; o repositório é público).

**Verificado a 2026-10-25:** migração aplicada pelo utilizador; `painel` bate com `compras` (total, contagem e soma de `por_mes`); `historico_compras` sem filtros devolve tantas linhas como `compras`; sem utilizador o total é 0; advisors sem avisos novos (só a "Leaked Password Protection" e o índice não usado já conhecidos).

---

## T2 · `fl_chart` e decisões [ ]

1. `pubspec.yaml`, em `dependencies` (ordem alfabética, entre `file_picker` e `flutter`): `fl_chart: 1.2.0` (versão exata, sem `^`).
2. `flutter pub get`; confirmar no `pubspec.lock` que ficou `1.2.0` e que não entrou nenhum outro pacote novo além de dependências já presentes.
3. Criar `docs/decisions/0006-fl-chart.md` e `docs/decisions/0007-painel-com-cache.md`, no formato de `0005-aprovacao-por-fase.md` (Estado, Opções consideradas, Decisão, Consequências), com o conteúdo de D1 e D2.
4. `flutter build web --dart-define-from-file=env/local.json` compila (prova de que o pacote funciona na web).

**Feito quando:** `analyze` e `test` verdes e o build web compila.

---

## T3 · Domínio: `lib/domain/estatisticas.dart` [ ]

Funções puras e modelos, sem Flutter nem Supabase. Escrever primeiro os testes (`test/estatisticas_test.dart`), depois o código.

```dart
/// Período dos filtros do Painel e do Histórico.
enum Periodo {
  esteMes('Este mês'),
  ultimos3Meses('Últimos 3 meses'),
  ultimos12Meses('Últimos 12 meses'),
  esteAno('Este ano'),
  tudo('Todo o histórico');

  const Periodo(this.rotulo);
  final String rotulo;
}

/// Datas inclusivas [de, ate] do período, a contar de [hoje] (só a data conta).
/// esteMes: dia 1 do mês de hoje → hoje.
/// ultimos3Meses: dia 1 do mês de há 2 meses → hoje (3 meses de calendário).
/// ultimos12Meses: dia 1 do mês de há 11 meses → hoje.
/// esteAno: 1 de janeiro → hoje.
/// tudo: 2000-01-01 → hoje.
({DateTime de, DateTime ate}) intervaloDe(Periodo p, DateTime hoje);

/// Filtro do painel e do histórico. Record: tem igualdade de valor (serve de
/// chave do provider family).
typedef FiltroCompras = ({Periodo periodo, String? lojaId});

class TotalMes { const TotalMes(this.mes, this.totalCent, this.nCompras);
  final DateTime mes; // dia 1 do mês
  final int totalCent; final int nCompras; }
class TotalLoja { const TotalLoja(this.lojaId, this.totalCent, this.nCompras);
  final String lojaId; final int totalCent; final int nCompras; }
class TotalCategoria { const TotalCategoria(this.categoriaId, this.totalCent);
  final String? categoriaId; /// null = sem categoria
  final int totalCent; }
class TotalArtigo { const TotalArtigo(this.artigoId, this.totalCent, this.nLinhas);
  final String artigoId; final int totalCent; final int nLinhas; }

/// Resultado da RPC painel.
class DadosPainel {
  const DadosPainel({required this.totalCent, required this.nCompras,
    required this.poupancaCent, required this.porMes, required this.porLoja,
    required this.porCategoria, required this.artigos});
  final int totalCent; final int nCompras; final int poupancaCent;
  final List<TotalMes> porMes; final List<TotalLoja> porLoja;
  final List<TotalCategoria> porCategoria; final List<TotalArtigo> artigos;

  /// Média por compra em cêntimos, arredondada; 0 se não há compras.
  int get mediaCent => nCompras == 0 ? 0 : (totalCent / nCompras).round();

  /// Lê o JSON da RPC (números podem chegar como int ou num).
  factory DadosPainel.fromJson(Map<String, dynamic> j);
  /// Mesmo formato que a RPC devolve (para a cache).
  Map<String, dynamic> toJson();
}

/// Um TotalMes por cada mês de [de] a [ate], com zeros nos meses sem compras.
List<TotalMes> mesesCompletos(List<TotalMes> porMes, DateTime de, DateTime ate);

/// As [n] primeiras categorias e o resto somado numa entrada "Outras"
/// (devolvida em `outrasCent`, 0 se não houver resto). A lista já vem ordenada.
({List<TotalCategoria> topo, int outrasCent}) categoriasTopo(
    List<TotalCategoria> todas, {int n = 8});

/// Resultado do painel com a origem: do servidor ou da cache.
class ResultadoPainel {
  const ResultadoPainel(this.dados, {this.guardadoEm});
  final DadosPainel dados;
  /// Preenchido quando os dados vêm da cache (sem rede).
  final DateTime? guardadoEm;
}

/// Uma compra no histórico (linha da RPC historico_compras).
class CompraResumo {
  const CompraResumo({required this.id, required this.lojaId, required this.data,
    this.local, required this.totalCent, required this.poupancaCent,
    required this.origem, required this.rever, required this.nLinhas});
  final String id; final String lojaId; final DateTime data; final String? local;
  final int totalCent; final int poupancaCent; final String origem;
  final bool rever; final int nLinhas;
  factory CompraResumo.fromMap(Map<String, dynamic> m);
}

/// Uma linha do talão, no detalhe da compra.
class LinhaCompra {
  const LinhaCompra({required this.id, this.artigoId, this.textoOriginal,
    this.quantidade, this.pesoG, this.precoUnitCent, required this.brutoCent,
    required this.descontoCent, required this.pagoCent});
  final String id; final String? artigoId; final String? textoOriginal;
  final int? quantidade; final int? pesoG; final int? precoUnitCent;
  final int brutoCent; final int descontoCent; final int pagoCent;
  factory LinhaCompra.fromMap(Map<String, dynamic> m);
}

/// Agrupa as compras (já ordenadas por data desc) por mês, mantendo a ordem.
List<({DateTime mes, List<CompraResumo> compras, int totalCent})> porMes(
    List<CompraResumo> compras);
```

Em `lib/domain/modelos.dart`: acrescentar `factory RegistoPreco.fromMap(Map<String, dynamic> m)` (lê `id, artigo_id, loja_id, data, preco_cent, origem`; `origem` com `OrigemPreco.values.byName`).

**Testes (`test/estatisticas_test.dart`)**:
- `intervaloDe` para os 5 períodos com `hoje = 2026-10-25`; `ultimos3Meses` e `ultimos12Meses` com `hoje = 2026-01-15` e `2026-02-28` (viragem de ano); `de` é sempre dia 1 (exceto `tudo`).
- `DadosPainel.fromJson(j).toJson()` devolve um mapa igual a `j` (JSON de exemplo com todas as chaves, uma categoria `null`); `fromJson` aceita números como `num` (ex.: `12.0`).
- `mediaCent`: 1000/3 → 333; 1001/2 → 501 (arredonda); 0 compras → 0.
- `mesesCompletos`: de 2026-08-01 a 2026-10-25 com só setembro → 3 meses, agosto e outubro a 0; ordem crescente.
- `categoriasTopo`: 10 categorias, n=8 → 8 no topo e `outrasCent` = soma das 2 últimas; 3 categorias → `outrasCent = 0`.
- `CompraResumo.fromMap`, `LinhaCompra.fromMap` e `RegistoPreco.fromMap` com campos opcionais a null.
- `porMes`: compras de out e set → 2 grupos, ordem mantida, totais certos.

**Feito quando:** testes verdes.

---

## T4 · Dados: repositório de estatísticas e histórico [ ]

**`lib/data/repositorios.dart`** (impacto: interface nova, nenhum implementador existente muda):
```dart
abstract interface class EstatisticasRepository {
  /// Painel do filtro. Com rede: chama a RPC e guarda na cache. Sem rede:
  /// devolve a cache (com guardadoEm) se for do mesmo intervalo; senão lança
  /// ErroDados('Sem rede e sem dados guardados para este filtro.').
  Future<ResultadoPainel> painel(FiltroCompras filtro, {DateTime? hoje});

  /// Compras do filtro (só com rede). [artigoIds] e [texto] filtram por linha.
  Future<List<CompraResumo>> compras(FiltroCompras filtro,
      {List<String>? artigoIds, String? texto, DateTime? hoje});

  /// Linhas de uma compra (só com rede).
  Future<List<LinhaCompra>> linhas(String compraId);
}
```
(`hoje` só existe para os testes; por omissão `DateTime.now()`.)

**`lib/data/supabase/supabase_estatisticas.dart`** (novo):
```dart
/// Chamada a uma RPC: nome e parâmetros → resposta crua. Injetável nos testes.
typedef ChamarRpc = Future<dynamic> Function(String nome, Map<String, dynamic> params);
/// Leitura das linhas de uma compra. Injetável nos testes.
typedef LerLinhas = Future<List<Map<String, dynamic>>> Function(String compraId);

class SupabaseEstatisticasRepository implements EstatisticasRepository {
  SupabaseEstatisticasRepository({required ChamarRpc rpc, required LerLinhas lerLinhas, required BaseLocal base});
  ...
}
```
- Datas para a RPC em `aaaa-mm-dd` (usar `dataIso` de `lib/domain/modelos.dart`, que já existe).
- **Painel:**
  - parâmetros `{'p_de', 'p_ate', 'p_loja'}`;
  - chave da cache: `'painel:${filtro.periodo.name}:${filtro.lojaId ?? 'todas'}'`;
  - valor guardado (JSON em texto): `{'de': 'aaaa-mm-dd', 'ate': 'aaaa-mm-dd', 'guardado_em': ISO-8601 UTC, 'dados': dados.toJson()}`;
  - erro de rede = qualquer exceção que **não** seja `ErroDados` depois de `comErrosTraduzidos` (o mesmo critério de `SupabaseConsultasCompras._comRede`). Um `ErroDados` (ex.: erro SQL) é relançado, não se usa a cache;
  - a cache só é usada se `de` e `ate` guardados forem iguais aos do intervalo atual (um "Este mês" de setembro não aparece em outubro).
- **Compras:** RPC `historico_compras` com `{'p_de', 'p_ate', 'p_loja', 'p_artigos', 'p_texto'}` (listas vazias e texto vazio enviados como `null`). Sem rede → `ErroDados('Sem rede: o histórico precisa do servidor.')`.
- **Linhas:** `lerLinhas(compraId)` → `LinhaCompra.fromMap`. Sem rede → a mesma mensagem.
- Construção real (em `providers.dart`): `rpc: (n, p) => cliente.rpc(n, params: p)`, `lerLinhas: (id) => cliente.from('linhas_compra').select().eq('compra_id', id)`.

**`lib/data/local/base_local.dart`** (impacto: `limparCache` é usado pelo sincronizador ao reiniciar): em `limparCache()`, apagar também as chaves `painel:%` (os dados foram apagados no servidor).

**`lib/data/providers.dart`** (impacto: só acrescenta):
```dart
final estatisticasRepositoryProvider = Provider<EstatisticasRepository>(...);
final painelProvider = FutureProvider.autoDispose.family<ResultadoPainel, FiltroCompras>(
  (ref, f) => ref.watch(estatisticasRepositoryProvider).painel(f));
```

**`lib/data/local/repositorios_locais.dart` + interface `ArtigosRepository`**: acrescentar
```dart
/// Registos de preço de um artigo (não apagados), por data crescente.
Stream<List<RegistoPreco>> observarRegistos(String artigoId);
```
(implementação: `_base.observarTabela('registos_preco')`, filtrar `artigo_id` e `apagado_em == null`, ordenar por `data` e depois `criado_em`). Atualizar **todos** os implementadores de `ArtigosRepository` (procurar com `rg "implements ArtigosRepository"`; em `test/` também). Provider: `registosPrecoProvider = StreamProvider.autoDispose.family<List<RegistoPreco>, String>`.

**Testes (`test/estatisticas_repositorio_test.dart`)**, com `BaseLocal(NativeDatabase.memory())` e `rpc`/`lerLinhas` falsos:
- com rede: devolve os dados, `guardadoEm == null`, e grava a chave `painel:esteMes:todas`;
- sem rede (o `rpc` falso lança `SocketException`) com cache do mesmo intervalo: devolve a cache com `guardadoEm` preenchido;
- sem rede com cache de outro intervalo (`hoje` noutro mês): lança `ErroDados`;
- sem rede e sem cache: lança `ErroDados`;
- `ErroDados` do servidor é relançado mesmo havendo cache;
- `compras` envia `p_artigos: null` e `p_texto: null` quando a pesquisa está vazia, e as listas certas quando não está (o `rpc` falso regista os parâmetros);
- `limparCache` apaga `painel:%` e mantém outras chaves de estado que não sejam `cursor:%`.
- Em `test/sync/` (ou novo teste com o `Dispositivo`): `observarRegistos` ignora apagados e de outros artigos e ordena por data.

**Feito quando:** testes verdes.

---

## T5 · Componentes comuns de gráficos: `lib/features/estatisticas/` [ ]

Pasta nova `lib/features/estatisticas/` (usada pelo Painel e pelo Ver artigo).

- `cores.dart`: `Color corDaLoja(Loja loja, ColorScheme esquema)` — converte `#rrggbb` em `Color(0xFFrrggbb)`; `null` ou inválido → `esquema.primary`. Teste: `'#eb6834'`, `'eb6834'` (inválido → primary), `null`.
- `barras_horizontais.dart`: `BarrasHorizontais({required List<({String rotulo, int cent, Color cor})> itens})` — **sem `fl_chart`**: cada linha é um `Row` com o rótulo (largura fixa 120 px, `maxLines: 2`), uma barra (`FractionallySizedBox(widthFactor: cent / maximo)` com altura 12 px e cantos arredondados) e o valor `formatarCent(cent)` à direita. `Semantics(label: '<rótulo>: <valor>')` por linha. Se `itens` estiver vazio, `Text('Sem dados no período.')`.
- `grafico_meses.dart`: `GraficoMeses({required List<TotalMes> meses})` com `BarChart` do `fl_chart`: uma barra por mês (`cor = colorScheme.primary`), eixo de baixo com o mês abreviado (`DateFormat('MMM', 'pt_PT')`, e o ano `'yy` em janeiro e na primeira barra), eixo esquerdo sem rótulos (os valores ficam no tooltip), tooltip com `formatarCent`. Altura 220 px. Envolver em `Semantics(label: 'Gasto por mês. ' + 'outubro 2026: 123,45 €; …')` + `ExcludeSemantics`.
- `grafico_preco.dart`: `GraficoPreco({required List<RegistoPreco> registos, required List<Loja> lojas})` com `LineChart`: uma linha por loja (`corDaLoja`), pontos visíveis, `isCurved: false`, x = dias desde o primeiro registo, y = `precoCent / 100`; tooltip com data e preço. Altura 200 px. Por baixo, uma legenda (bolinha da cor + nome da loja). Se houver **menos de 2 registos no total**, não desenhar o gráfico: mostrar `Text('Ainda não há registos suficientes para o gráfico.')`. `Semantics` com o último preço por loja.

**Testes (`test/graficos_test.dart`)** (widget tests, com `MaterialApp(theme: construirTema(Brightness.light, fontesGoogle: false))`, de `lib/core/tema.dart`; o mesmo em todos os testes de widgets desta fase, para não pedir letras à rede):
- `BarrasHorizontais` mostra rótulos e valores formatados; lista vazia mostra a mensagem;
- `GraficoMeses` com 3 meses encontra um `BarChart` e o `Semantics` com os 3 valores;
- `GraficoPreco` com 1 registo mostra a mensagem; com 3 registos em 2 lojas encontra um `LineChart` e a legenda com as 2 lojas;
- `corDaLoja` (teste unitário).

**Feito quando:** testes verdes.

---

## T6 · Ecrã Painel: `lib/features/painel/painel_page.dart` [ ]

Router (`lib/core/router.dart`, impacto: só a rota `/painel`): trocar `EmBrevePage(titulo: 'Painel e estatísticas', fase: 2)` por `PainelPage()`.

`PainelPage` (`ConsumerStatefulWidget`), dentro de `Pagina(titulo: 'Painel e estatísticas', …)`:
1. **Filtros** (no topo, em `Wrap` com `spacing: 16`; cada menu com largura 260 px, ou a largura toda abaixo de 600 px — o mesmo padrão de `artigos_page.dart`):
   - "Período": `DropdownButtonFormField<Periodo>` com os 5 rótulos; por omissão `Periodo.esteMes`;
   - "Loja": `DropdownButtonFormField<String?>` com "Todas as lojas" (`null`) e as lojas não apagadas de `lojasProvider` (incluir as arquivadas, porque têm compras).
   - O filtro escolhido não é guardado entre sessões.
2. `ref.watch(painelProvider((periodo: _periodo, lojaId: _lojaId)))`:
   - a carregar: `CircularProgressIndicator` centrado;
   - erro: `Text('$erro')` centrado e um `TextButton('Tentar outra vez')` que faz `ref.invalidate(...)`;
   - dados: o conteúdo abaixo, dentro de `RefreshIndicator` (puxar para atualizar = `ref.refresh(...).future`).
3. **Aviso de cache** (só se `guardadoEm != null`): um `Card` com `colorScheme.tertiaryContainer`, ícone `Icons.cloud_off` e `'Dados de ${formatarData(guardadoEm)} às HH:mm; sem rede.'` (hora local).
4. **Números** (4 cartões, `Wrap`, cada um com largura mínima 160 px): "Total gasto" (`formatarCent(totalCent)`), "Compras" (`formatarInteiro(nCompras)`), "Média por compra" (`formatarCent(mediaCent)`), "Poupança" (`formatarCent(poupancaCent)`).
5. **Secções**, cada uma num `Card` com título (`titleMedium`):
   - "Gasto por mês": `GraficoMeses(meses: mesesCompletos(porMes, de, ate))`. Só aparece se o intervalo tiver mais de 1 mês. Para `Periodo.tudo`, `de` = primeiro mês de `porMes` (não 2000-01).
   - "Por loja": `BarrasHorizontais` com o nome e a cor de cada loja (`corDaLoja`). Só com "Todas as lojas". Loja que já não existe na cache → rótulo "Loja apagada".
   - "Por categoria": `categoriasTopo(porCategoria)`; rótulo = nome da categoria, "Sem categoria" (`null`) ou "Outras" (`outrasCent > 0`); cor `colorScheme.primary`. Nota em `bodySmall` por baixo: "Soma das linhas dos talões; pode diferir ligeiramente do total."
   - "Artigos com mais gasto": lista (`ListTile` denso) com o nome do artigo (de `artigosProvider`; se não existir, "Artigo apagado"), subtítulo `'${nLinhas}× comprado'`, valor à direita. Tocar abre `DialogoVerArtigo` (T8).
   - Com `nCompras == 0`: em vez das secções, `Text('Não há compras neste período.')`.
6. **Layout:** conteúdo num `ListView` com `padding: EdgeInsets.all(16)`, centrado e com `maxWidth: 1100`. A partir de 800 px (`larguraEcraLargo`), as secções "Por loja" e "Por categoria" ficam lado a lado (`Row` com dois `Expanded`); abaixo, em coluna.

**Testes (`test/painel_page_test.dart`)**, com `ProviderScope(overrides: [estatisticasRepositoryProvider.overrideWithValue(fake), lojasProvider…, categoriasProvider…, artigosProvider…])`:
- mostra os 4 números formatados;
- com `guardadoEm` mostra o aviso "sem rede";
- mudar o "Período" volta a pedir o painel com o filtro novo (o fake regista os filtros);
- com `nCompras = 0` mostra "Não há compras neste período.";
- erro mostra a mensagem e "Tentar outra vez";
- largura 1000 px: "Por loja" e "Por categoria" estão na mesma linha (comparar `tester.getTopLeft(...).dy`); largura 400 px: em coluna.

**Feito quando:** testes verdes e verificação visual (claro/escuro, < e > 800 px) feita com `flutter run -d chrome --dart-define-from-file=env/local.json`.

---

## T7 · Ecrã Histórico: `lib/features/historico/` [ ]

Router: trocar `EmBrevePage(titulo: 'Histórico', fase: 2)` por `HistoricoPage()`. Depois desta tarefa, se `EmBrevePage` deixar de ser usada, apagá-la (`lib/features/em_breve/`) e o import no router.

**`historico_page.dart`** (`ConsumerStatefulWidget`), em `Pagina(titulo: 'Histórico', …)`:
1. **Filtros:** "Período" (por omissão `Periodo.ultimos12Meses`), "Loja" (como no Painel) e "Pesquisar" (`TextField` com ícone de lupa, `hintText: 'Artigo ou texto do talão'`). A pesquisa só é enviada 400 ms depois da última tecla (um `Timer` cancelado no `dispose`) ou ao carregar em Enter.
2. **Pesquisa:** com o termo `t = normalizar(texto.trim())` não vazio:
   - `artigoIds` = ids dos artigos de `artigosProvider` cujo `normalizar(nome)` contém `t`, mais os de `aliasesProvider` cujo `normalizar(alias)` contém `t`, mais os artigos cujo `ean` contém o texto (sem normalizar);
   - `texto` = o texto escrito (`trim()`), para procurar no `texto_original`.
   - Pôr esta escolha numa função pura `({List<String> artigoIds, String? texto}) termosPesquisa(String escrito, List<Artigo> artigos, Map<String, List<String>> aliases)` em `lib/features/historico/pesquisa.dart`, com testes.
3. **Carregamento:** `FutureProvider.autoDispose.family` local à feature (`comprasHistoricoProvider`) com chave `({FiltroCompras filtro, List<String> artigoIds, String? texto})` — atenção: listas não têm igualdade de valor; usar `String artigosChave = artigoIds.join(',')` na chave do record em vez da lista, e reconstruir a lista dentro do provider. Estados de carregamento e erro como no Painel (o erro sem rede mostra a mensagem do repositório).
4. **Lista:** `porMes(compras)` → para cada mês, um cabeçalho fixo com "outubro de 2026 · 12 compras · 456,78 €" (`DateFormat("MMMM 'de' y", 'pt_PT')`), e por baixo um `ListTile` por compra:
   - leading: bolinha com `corDaLoja`;
   - título: nome da loja e, se houver, " · <local>";
   - subtítulo: `formatarData(data)` e `'${nLinhas} artigos'`; se `poupancaCent > 0`, " · poupou X";
   - trailing: `formatarCent(totalCent)`;
   - `rever == true`: ícone `Icons.error_outline` com `Tooltip('A soma das linhas não bate com o total')`.
   - Sem compras: "Nenhuma compra encontrada." (com pesquisa) ou "Não há compras neste período.".
5. Tocar numa compra: **< 800 px** abre `DetalheCompraPage` com `Navigator.push` (`MaterialPageRoute`); **≥ 800 px** mostra o detalhe à direita (lista com 420 px, detalhe no resto, separados por `VerticalDivider`), e a compra selecionada fica marcada (`selected: true`).

**`detalhe_compra.dart`**: `DetalheCompra({required CompraResumo compra})` (o painel do detalhe) e `DetalheCompraPage` (o mesmo dentro de um `Scaffold` com `AppBar(title: Text(nomeDaLoja))`).
- Cabeçalho: loja, local, data, total, poupança (se > 0), origem traduzida (`talao` → "Talão", `manual` → "Registada à mão", `importacao` → "Importada", `lista` → "Concluir compra") e o aviso de `rever`.
- Linhas: `ref.watch` de um `FutureProvider.autoDispose.family<List<LinhaCompra>, String>` (`linhasCompraProvider`, em `lib/data/providers.dart`). Ordenadas pelo nome mostrado (o talão não guarda a ordem). Cada linha:
  - título: nome do artigo (de `artigosProvider`) ou, se não houver, `textoOriginal`, ou "—";
  - subtítulo: quantidade (`'2 un'`) ou peso (`'0,794 kg'`, com `pesoG / 1000` só para mostrar, 3 casas decimais) e o preço unitário (`formatarCent`, com "/kg" quando há peso); se o nome vier do artigo e `textoOriginal` for diferente, mostrar também o texto do talão em `bodySmall`;
  - trailing: `formatarCent(pagoCent)` e, se `descontoCent > 0`, por baixo `-${formatarCent(descontoCent)}` em `colorScheme.primary`.
- Rodapé: "Soma das linhas: X" (soma de `pagoCent`, em inteiros).
- Tocar numa linha com `artigoId` abre `DialogoVerArtigo` (T8).

**Testes:**
- `test/pesquisa_historico_test.dart`: `termosPesquisa` com acentos ("maca" encontra "Maçã"), por alias, por EAN parcial, texto vazio → `artigoIds` vazio e `texto` null.
- `test/historico_page_test.dart` (fake `EstatisticasRepository`): agrupa por mês com o cabeçalho certo; escrever "maca" e esperar 400 ms envia o id da Maçã; tocar numa compra a 400 px de largura abre `DetalheCompraPage`; a 1000 px mostra o detalhe ao lado; erro sem rede mostra a mensagem.
- `test/detalhe_compra_test.dart`: nome do artigo vs. texto do talão; peso formatado "0,794 kg"; desconto; "Soma das linhas".

**Feito quando:** testes verdes e verificação visual como em T6.

---

## T8 · "Ver artigo" com evolução do preço [ ]

1. Mover `DialogoVerArtigo` de `lib/features/lista/dialogos_lista.dart` para **`lib/features/artigos/ver_artigo.dart`** (sem mudar o comportamento atual) e atualizar os imports (`lista_page.dart`). Confirmar com `rg DialogoVerArtigo` que não fica nenhuma referência antiga.
2. No diálogo, depois dos preços por loja e antes das ações: secção "Evolução do preço" (`titleSmall`) com `GraficoPreco(registos: ref.watch(registosPrecoProvider(artigo.id)).value ?? const [], lojas: lojas)`. O conteúdo do diálogo passa a estar num `SingleChildScrollView` (para caber no telemóvel), com largura 480 px.
3. Em Artigos (`lib/features/artigos/artigos_page.dart`), no menu ⋮ de cada artigo, acrescentar **"Ver"** como primeira opção (`PopupMenuItem(value: 'ver', child: Text('Ver'))`), que abre `DialogoVerArtigo(artigo: a)`.
4. No Painel ("Artigos com mais gasto") e no detalhe da compra, tocar abre o mesmo diálogo.

**Testes (`test/ver_artigo_test.dart`)**: com 3 registos o diálogo mostra "Evolução do preço" e um `LineChart`; com 1 registo mostra a mensagem; os botões "Editar" e "Fechar" continuam a funcionar (teste do comportamento que já existia: "Fechar" fecha o diálogo).

**Feito quando:** testes verdes, e no telemóvel o "Ver" em Artigos abre o diálogo com o gráfico.

---

## T9 · Documentação e fecho [ ]

- `docs/architecture/mapa.md`: `lib/domain/estatisticas.dart`, `lib/data/supabase/supabase_estatisticas.dart`, `lib/features/estatisticas/`, `lib/features/painel/`, `lib/features/historico/`, `lib/features/artigos/ver_artigo.dart`, migração `fase2` (`painel`, `historico_compras`); retirar `em_breve` se foi apagada.
- `docs/architecture/sincronizacao.md`: "A cache do Painel (`estado`, chaves `painel:%`) não sincroniza; é apagada por `limparCache` (reinício) e por `limparTudo` (sair)."
- `docs/ESTADO.md`: fase 2 em portão; ecrãs feitos.
- Marcar T1–T9 aqui.
- Notas fora do âmbito que surgirem → `docs/planning/notas.md`.

---

## Portão da Fase 2

1. `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos, `flutter test --reporter compact` verde, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. Migração aplicada e verificada (T1), advisors sem avisos novos.
3. **Números certos (com SQL de controlo):** o Painel com "Todo o histórico" e "Todas as lojas" mostra o mesmo total e número de compras que `select sum(total_cent), count(*) from public.compras`; com uma loja, o mesmo que o SQL filtrado por `loja_id`; "Este mês" igual ao SQL com `data >= date_trunc('month', current_date)`.
4. **Histórico:** "Todo o histórico" mostra tantas compras como o SQL; pesquisar um artigo comum (ex.: "leite") devolve as mesmas compras que o SQL com `exists` nas linhas; o detalhe de uma compra mostra a mesma soma das linhas que o SQL.
5. **Sem rede (modo de avião no telemóvel):** o Painel abre com o aviso "Dados de …; sem rede" para um filtro já visto, e com a mensagem de erro para um filtro nunca visto; o Histórico mostra "Sem rede: o histórico precisa do servidor."; o "Ver artigo" mostra o gráfico do preço.
6. Verificação visual: Painel, Histórico, detalhe e Ver artigo em claro e escuro, abaixo e acima de 800 px, na web e no Android (`adb install -r`).
7. `docs/` atualizado (T9). O utilizador confirma o portão; só então o push.

## Commits (um por tarefa)
1. `Fase 2: migração com as RPC painel e historico_compras`
2. `Pacote fl_chart 1.2.0 e decisões 0006 e 0007`
3. `Domínio das estatísticas: períodos, painel e histórico`
4. `Dados: repositório de estatísticas com cache do painel e registos de preço`
5. `Gráficos: barras, meses e evolução do preço`
6. `Ecrã Painel`
7. `Ecrã Histórico e detalhe da compra`
8. `Ver artigo: evolução do preço e acesso a partir de Artigos`
9. `docs: Fase 2`

## Depois da Fase 2
- Importação de talões em PDF e por fotografia (ML Kit, só no Android).
- Avisos de preço.
- Orçamento mensal.
- Comparação de preços P1 (`docs/comparacao-precos/`).
- Fora de âmbito: iOS.
