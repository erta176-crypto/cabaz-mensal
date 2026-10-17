# Cabaz Mensal · instruções para o Claude

App Flutter (Android + web no GitHub Pages) sobre Supabase para registar compras de supermercado. Responder sempre em português de Portugal.

## Regras obrigatórias

### 1. Perguntas sobre o código ou pedidos de alteração: consultar primeiro o graphify
Antes de qualquer `grep`, pesquisa ou leitura de ficheiros:
- `graphify query "<pergunta>"` para perguntas gerais;
- `graphify explain "<conceito>"` para uma classe, função ou tabela;
- `graphify path "<A>" "<B>"` para a ligação entre duas peças.

Ler ficheiros diretamente só nas linhas que o grafo (ou uma leitura anterior) já localizou. Pôr esta regra no prompt de qualquer subagente que explore código.

Antes de alterar um ficheiro partilhado — repositórios (`lib/data/repositorios.dart` e implementações), base de dados (`lib/data/local/base_local.dart`, `supabase/migrations/`), providers (`lib/data/providers.dart`) ou entidades (`lib/domain/`) — mostrar ao utilizador o impacto (o que depende dele, segundo o grafo) **antes** de editar.

Limitação: os nós SQL (tabelas, funções como `public.concluir_compra`) não estão ligados ao código Dart que os chama por texto (`rpc('concluir_compra')`, `from('itens_lista')`). Para impacto na base de dados, completar o grafo com uma pesquisa por esse nome no Dart.

### 2. Sempre que houver alteração no código: atualizar o graphify e este CLAUDE.md
No fim de qualquer tarefa que altere código, antes de a dar por terminada:
1. Correr `graphify update .` na raiz do projeto. Há também um hook `Stop` em `.claude/settings.json` que o faz automaticamente quando `lib/`, `test/` ou `supabase/migrations/` mudaram; confirmar que correu.
2. Atualizar a secção **Mapa do projeto** deste ficheiro se a alteração mudar o que lá está descrito: pastas ou ficheiros novos, tabelas ou funções novas, novas regras de sincronização, fases concluídas.

Só depois destes dois passos a tarefa está terminada.

## graphify
- O grafo está em `graphify-out/` e é **só local**: está no `.gitignore` e reconstrói-se com `graphify update .`, que só analisa o código, sem custo de API.
- O `.graphifyignore` exclui o código compilado do drift (`web/drift_worker.js`, `web/sqlite3.wasm`) e, por segurança, `build/`, `dados-privados/` e `env/`.
- Se existir `graphify-out/wiki/index.md`, usá-lo para navegação geral.
- Ler `graphify-out/GRAPH_REPORT.md` só para uma revisão geral da arquitetura, ou quando query/path/explain não chegarem.

## Mapa do projeto
*Manter atualizado (regra 2).*

- **Estado (2026-10-17):** Fase 0 e Fase 1A concluídas e publicadas. O plano da Fase 1B (importar e exportar CSV, XLSX, PDF e TXT) está aprovado e adiado, em `~/.claude/plans/tidy-conjuring-squirrel.md`.
- **`lib/domain/`:** modelos e regras puras.
  - Dinheiro sempre em cêntimos inteiros e pesos em gramas (`dinheiro.dart`).
  - Pesquisa sem acentos (`texto.dart`).
  - Cálculos de Concluir compra (`compra.dart`).
  - Preferências e gestos (`preferencias.dart`).
- **`lib/data/`:** só esta pasta fala com o Supabase e com o drift.
  - `repositorios.dart`: as interfaces.
  - `providers.dart`: os providers Riverpod.
  - `local/`: base drift genérica (tabela `registos` com JSON por linha, fila `pendentes`, `estado`) e os repositórios locais.
  - `sync/`: a sincronização.
    - `escrita.dart`: grava na cache e põe na fila. Criar envia a linha completa; editar envia só as colunas alteradas.
    - `sincronizador.dart`: envio por ordem com espera crescente, e receção por `atualizado_em` com margem de 5 min.
    - `servidor_supabase.dart`: a ligação ao Supabase.
  - `supabase/`: autenticação, consultas de compras e dados (importar, exportar, apagar, resumo).
- **`lib/import/`:** cópia completa JSON (formato v2 do `cabaz-seed.json`).
- **`lib/features/`:** um diretório por ecrã: `shell` (navegação com corte a 800 px e faixa de sincronização), `entrada`, `lista` (Lista do mês e Concluir compra), `artigos`, `importar_exportar`, `definicoes` e `em_breve`.
- **`supabase/migrations/`:** `fase0` (tabelas, RLS, `importar_seed`) e `fase1a` (`apagado_em`, lista do mês, `preferencias`, `concluir_compra`). As migrações são aplicadas pelo utilizador no SQL Editor; o `apply_migration` é recusado pelas permissões.
- **Regras de sincronização:**
  - `itens_lista` e `aliases` sincronizam pela chave natural;
  - eliminar marca `apagado_em`;
  - `preferencias.reiniciado_em` manda limpar a cache;
  - vence a última escrita a chegar ao servidor.
- **Testes** (`test/`): servidor falso em memória e drift em memória (`test/sync/`). Nenhum teste usa o Supabase real.

## Forma de trabalhar
- Planear primeiro e esperar aprovação. As notas do utilizador entram no plano.
- Commits pequenos em português. Push só depois de o utilizador confirmar o portão de cada fase.
- Verificar cada passo do portão no servidor (SQL e logs) antes de declarar sucesso.
- No telemóvel, instalar com `adb install -r` para não apagar os dados locais.
- Nunca commitar `dados-privados/` nem `env/`.
