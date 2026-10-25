# Comparação de preços · P0 · Modelo de dados, EAN e origem do preço

Plano escrito a 23/10/2026 e aprovado a 25/10/2026. **Estado:** código e testes feitos a 25/10/2026; falta aplicar a migração no SQL Editor e passar o portão (secção 6).

## 1. Enquadramento

O módulo de comparação de preços (inspirado na Preço Fresco) entra **dentro** do Cabaz Mensal. Fases:

| Fase | Conteúdo |
|---|---|
| **P0** | Auditar o modelo de dados e acrescentar EAN e origem do preço (este documento) |
| P1 | Primeiro conector (uma loja), numa Edge Function do Supabase, isolado do resto |
| P2 | Ecrã Comparar com pesquisa por nome |
| P3 | Scan de código de barras (só Android) |
| P4 | Descontos |
| P5 | Ligação à lista de compras e ao alerta de 10 % |

### Plataforma atual (confirmada no repositório)

O pedido fala em "PWA", mas a app **já não é uma PWA desde 13/10/2026**. Hoje é:

- **Flutter**, com o mesmo código para **Android** (APK) e **web** (publicada no GitHub Pages);
- **Supabase** como fonte de verdade (projeto `cabaz-mensal`, eu-west-1), com autenticação, RLS por `user_id` e migrações em `supabase/migrations/`;
- cache local em **drift** (também na web) e fila de alterações para trabalhar sem rede.

Neste plano, "PWA" passa a ler-se como **"versão web"**. O que estava decidido mantém-se: a app (web ou Android) nunca consulta as lojas diretamente, só o Supabase; o scan fica só no Android e a web tem a pesquisa por nome.

## 2. Auditoria do modelo atual

Fontes: as migrações `20261015000000_fase0.sql` e `20261015120000_fase1a.sql`, o código Dart em `lib/`, e o esquema real lido pelo MCP do Supabase (`list_tables` e consultas SQL só de leitura) a 23/10/2026.

### 2.1 Tabelas (todas com `id` UUID, `user_id`, `criado_em`, `atualizado_em` e RLS só para o dono)

| Tabela | Linhas | Papel | Notas para a comparação de preços |
|---|---:|---|---|
| `lojas` | 3 | Lidl, Pingo Doce, Mercadona (`slug`, `nome`, `cadeia`, `cor`, `arquivada`) | `cadeia` já existe e serve para ligar uma loja do utilizador a um conector online |
| `categorias` | 15 | Categorias dos artigos | Sem impacto |
| `artigos` | 693 | Artigo genérico do utilizador (`nome`, `categoria_id`, `unidade` un/kg, `ativo`) | **Não tem EAN.** Recebe a coluna nova |
| `aliases` | 688 | Texto do talão → artigo, por loja | Modelo a copiar se um dia houver vários EAN por artigo (ver 6.1) |
| `registos_preco` | 1 745 | Preços registados pelo utilizador (`data`, `preco_cent`, `origem` talao/manual/lista) | São os "meus registos": ficam como estão e não expiram |
| `itens_lista` | 176 | Lista do mês por loja | Sem impacto no P0 (P5 e Fase 1C) |
| `compras` | 138 | Compras reais (total 4 652,26 €) | Sem impacto. Não expiram |
| `linhas_compra` | 1 695 | Linhas dos talões | Sem impacto |
| `preferencias` | 1 | Preferências em JSON e `reiniciado_em` | Pode guardar o limiar e a validade, se forem configuráveis (P5) |

Views: `resumo_por_loja` e `precos_atuais` (preço mais recente por artigo e loja; ignora apagados).
Funções: `set_atualizado_em`, `itens_lista_qtd_inicial`, `apagar_todos_dados`, `importar_seed`, `concluir_compra`, e ainda `agora` e `importar_lote` (ver 2.3).
Extensões ativas: `plpgsql`, `pgcrypto`, `uuid-ossp`, `pg_stat_statements`, `supabase_vault`. Ainda não há `pg_cron` nem `pg_net`.
Tamanho da base de dados: **15 MB** (o limite gratuito é 500 MB).

### 2.2 O que já existe sobre "origem do preço"

- `registos_preco.origem` já existe, mas diz **como** eu registei o preço: `talao` (1 695 linhas), `lista` (50, vindas da importação da PWA antiga) e `manual` (Concluir compra e edição do artigo; ainda nenhuma linha).
- Não existe nada que distinga **"registado por mim"** de **"pesquisado online"**, porque ainda não há preços online.
- Os 1 745 registos vão de 04/04/2025 a 07/10/2026. Há 711 pares artigo/loja e 24 casos com mais de um registo no mesmo dia; o preço atual desempata pelo `criado_em`.

### 2.3 Diferenças entre o repositório e a base de dados real

1. **`importar_lote(jsonb)` e `agora()` existem no Supabase mas não estão em nenhuma migração do repositório** nem no código do `main`. Devem vir do trabalho da Fase 1B, que ainda não foi enviado para o GitHub. O P0 tem de alterar `importar_lote` (para aceitar o EAN), por isso a 1B deve entrar no `main` antes do P0, ou o P0 passa a ser a primeira migração a guardar essa função no repositório.
2. `list_migrations` está vazio: as migrações foram aplicadas no SQL Editor, por isso o Supabase não tem histórico. O repositório é a única fonte do histórico do esquema.
3. A `concluir_compra` da base de dados é igual à do repositório (grava preços com `origem = 'manual'`).

### 2.4 Como a app lê e escreve estes dados (pontos a mexer)

- **Cache local genérica** (`lib/data/local/base_local.dart`): cada linha é guardada como JSON na tabela `registos`. **Uma coluna nova no Supabase não precisa de migração drift**: chega no JSON e só o modelo Dart a tem de ler.
- `Artigo.fromMap/toMap` (`lib/domain/modelos.dart`): é aqui que entra o `ean`.
- `LocalArtigosRepository.guardar` (`lib/data/local/repositorios_locais.dart`): ao editar, envia `toMap()` sem o `id`; o `ean` passa a ir junto.
- `precosAtuaisDe` (o mesmo ficheiro) imita a view `precos_atuais` no telemóvel; `PrecoAtual` é usado em Artigos, Lista, Concluir compra e no diálogo "Ver artigo".
- Cópia JSON v2: `lib/import/exportar.dart`, `seed_modelo.dart` e `importar_seed.dart`, mais as funções `importar_seed` e `importar_lote` no servidor.
- Diálogo de criar e editar artigo: `lib/features/artigos/dialogos.dart`.

## 3. O que o P0 acrescenta

### 3.1 EAN opcional no artigo

**Servidor (migração nova `supabase/migrations/2026102xxxxxxx_p0_ean.sql`):**

```sql
alter table public.artigos add column ean text;
alter table public.artigos add constraint artigos_ean_formato
  check (ean is null or ean ~ '^([0-9]{8}|[0-9]{13}|[0-9]{14})$');
create index artigos_user_id_ean_idx on public.artigos (user_id, ean) where ean is not null;
```

- Só dígitos. Guarda-se EAN-8, EAN-13 ou GTIN-14. Um UPC-A (12 dígitos) é convertido em EAN-13 com um `0` à frente antes de gravar, para o mesmo produto ter sempre o mesmo código.
- O dígito de controlo é validado no Dart (função pura, com testes), não no Postgres.
- **Sem índice único.** Dois dispositivos sem rede podiam dar o mesmo EAN a artigos diferentes, e um erro 23505 bloquearia a fila de sincronização. A app avisa "este código já está no artigo X" antes de gravar, e o índice serve para procurar depressa por EAN (no P3).
- Os 693 artigos atuais ficam com `ean = null`. Não se altera nenhum dado.
- `importar_seed` e `importar_lote` passam a ler `ean` (campo opcional) com `create or replace`.
- A ordem da Fase 1A mantém-se: as funções usam o prefixo `public.` e `search_path` vazio.

**App:**

- `lib/domain/ean.dart` (novo): `normalizarEan(String) → String?` e `eanValido(String) → bool` (dígito de controlo GS1).
- `Artigo` ganha `final String? ean`, e `fromMap`, `toMap` e `copyWith` passam a incluí-lo. Um JSON antigo sem `ean` continua a ler-se.
- O diálogo do artigo ganha o campo **"Código de barras (opcional)"**, com teclado numérico, validação e o aviso de duplicado.
- Cópia JSON v2: `ean` opcional nos artigos (a versão continua a ser 2, porque um ficheiro antigo continua válido).

### 3.2 Origem do preço: "registado por mim" ou "pesquisado online"

A coluna `origem` já está ocupada (talão, manual, lista), por isso o nome novo é **`fonte`**, com dois valores: `registado` e `online`.

Leitura escolhida (a confirmar no PR): como os meus registos ficam à parte e não expiram, **os preços online não entram em `registos_preco`** (ver 4). A `fonte` vive por isso no **preço atual**, que é o que os ecrãs mostram:

- a view `precos_atuais` ganha a coluna `fonte` (no P0 é sempre `'registado'`);
- `PrecoAtual` ganha `final FontePreco fonte` (`enum FontePreco { registado, online }`) e `final bool desatualizado` (no P0 é sempre `false`; os registos manuais nunca expiram);
- `precosAtuaisDe` preenche `fonte: registado`.

No P1, quando existir a tabela de preços online, a view e o `precosAtuaisDe` passam a juntar as duas origens. Os ecrãs já recebem a `fonte` e o `desatualizado` e só têm de os mostrar (no P2).

**Alternativa**, se a intenção era outra: pôr `fonte` em `registos_preco` e gravar lá também os preços online. Não a recomendo, porque mistura dados que expiram com dados que não expiram e obriga a filtrar a `fonte` em todas as estatísticas de compras reais.

### 3.3 O que o P0 não faz

Não cria tabelas de preços online, não cria Edge Functions, não liga `pg_cron`, não cria ecrãs novos e não acrescenta pacotes. Isto fica para o P1 e seguintes.

## 4. Esboço do P1 (só para validar que o P0 encaixa; não se cria agora)

| Tabela | Chave | Conteúdo |
|---|---|---|
| `precos_online` | `(cadeia, codigo_loja)` | `ean`, `nome`, `marca`, `quantidade`, `preco_cent`, `preco_ref_cent` (€/kg ou €/L), `promo_cent`, `promo_ate`, `obtido_em`, `valido_ate = obtido_em + 30 dias`. **Uma linha por produto e loja**, atualizada com `upsert`; nunca se acrescentam linhas |
| `precos_online_historico` | `(cadeia, codigo_loja, mes)` | Resumo mensal (mín., média e máx.) atualizado quando o preço muda. Limpeza automática dos meses com mais de N meses (a decidir no P1) |

- **Dados globais, sem `user_id`**: o preço de uma loja é igual para todos. RLS: leitura para `authenticated`; escrita só pela Edge Function (`service_role`).
- A ligação ao artigo do utilizador faz-se por `artigos.ean = precos_online.ean` e por `lojas.cadeia = precos_online.cadeia`. Por isso o EAN entra já no P0.
- Um produto "desatualizado" é aquele com `valido_ate < now()`. A linha não se apaga logo: continua a mostrar-se como desatualizada até ser renovada ou limpa.
- Volume estimado: com 20 000 produtos de uma loja, a cerca de 300 bytes cada, são uns 6 MB, mais uns 3 MB por mês de histórico mensal. Cabe nos 500 MB, mas convém guardar histórico só dos produtos que tenho como artigos ou que pesquisei (a decidir no P1).
- Pausa do plano gratuito ao fim de 7 dias sem atividade: **não confirmei** se um `pg_cron` interno conta como atividade. Fica para verificar no P1.

## 5. Passos do P0 (para o agente executar depois de aprovado)

Antes de mexer em ficheiros partilhados (`modelos.dart`, `repositorios_locais.dart`, `supabase/migrations/`), mostrar o impacto segundo o graphify, como manda o `CLAUDE.md`.

1. [x] **Pré-requisito:** a Fase 1B no `main` (`20261018000000_fase1b.sql` guarda `importar_lote` e `agora`).
2. [x] Escrever a migração `20261025000000_p0_ean.sql`: coluna, `check`, índice, `create or replace` de `importar_seed` e `importar_lote` com `ean`, e `create or replace view public.precos_atuais` com `fonte`.
3. [ ] O utilizador aplica a migração no SQL Editor (o `apply_migration` é recusado). Depois corre-se `get_advisors` (segurança e desempenho).
4. [x] Criar `lib/domain/ean.dart` e os testes. Ficou só `normalizarEan` (devolve null se inválido); `eanValido` seria redundante.
5. [x] Pôr o `ean` em `Artigo` (o `Artigo` não tem `copyWith`) e o `fonte` e o `desatualizado` em `PrecoAtual`, mais o `precosAtuaisDe`.
6. [x] Acrescentar o campo EAN e o aviso de duplicado ao diálogo do artigo.
7. [x] Acrescentar o `ean` à cópia JSON (exportar, `seed_modelo`, `importar_seed`).
8. [x] Correr `dart format --set-exit-if-changed .`, `flutter analyze` e `flutter test`, e depois `graphify update .`. Atualizar `docs/architecture/mapa.md`.

### Testes novos

- `test/ean_test.dart`: EAN-8, EAN-13, GTIN-14 e UPC-A válidos; dígito de controlo errado; letras e espaços; normalização de 12 para 13 dígitos.
- `Artigo`: ida e volta `toMap`/`fromMap` com e sem `ean`, e um JSON antigo sem a chave.
- `precosAtuaisDe`: devolve `fonte = registado` e `desatualizado = false`.
- Cópia JSON: exportar e importar mantém o EAN, e um ficheiro v2 antigo sem `ean` continua a importar.
- Sincronização (servidor falso): criar um artigo com EAN num dispositivo e vê-lo no outro. Editar no dispositivo antigo, sem `ean` no modelo, não apaga o EAN (a edição só envia as colunas alteradas).

## 6. Portão do P0

1. A migração foi aplicada e o `get_advisors` não dá avisos novos.
2. SQL: 693 artigos, todos com `ean is null`; 1 745 `registos_preco` sem alterações; 138 compras com 4 652,26 €; a view `precos_atuais` devolve `fonte = 'registado'` em todas as linhas.
3. SQL: `insert` de um artigo com `ean = '123'` falha pelo `check`.
4. No Android: criar um artigo com o EAN de um produto real. Aparece na web depois da sincronização.
5. Um EAN com o dígito de controlo errado é recusado. Um EAN repetido mostra o aviso.
6. Exportar a cópia JSON, importar, e o EAN mantém-se.
7. `dart format`, `flutter analyze` (sem avisos) e `flutter test` verdes, com a saída real.

### 6.1 Ponto a decidir (não bloqueia o P0)

O artigo é genérico ("Leite meio-gordo") e pode ser comprado em várias lojas com marcas diferentes (Milbona no Lidl, marca Pingo Doce no Pingo Doce). Cada marca tem o seu EAN, por isso **um só EAN por artigo** só compara bem produtos de marca igual em todas as lojas. Isto fica como está, porque foi o que se decidiu. Se no P2 ou no P3 fizer falta, acrescenta-se uma tabela `artigos_ean (artigo_id, ean, loja_id opcional)`, ao jeito dos `aliases`, sem mudar o que o P0 cria.

## 7. O que não consegui verificar

- O código da Fase 1B (`importar_lote`) não está no GitHub, por isso não vi como a app o chama.
- Não corri `flutter analyze` nem os testes, porque este PR só tem documentação. O graphify não estava instalado neste ambiente: a auditoria foi feita com `rg` e com a leitura dos ficheiros indicados.
- As políticas RLS confirmam-se pela contagem: 4 por tabela (select, insert, update e delete do dono) nas 9 tabelas. Não comparei o texto de cada política nem os triggers com as migrações.
