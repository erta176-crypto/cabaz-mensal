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

## Modo de trabalho (obrigatório)

**Foco**
- Faz só o que a fase/tarefa pede. Nada de refatorações, pacotes, ecrãs ou "melhorias" não pedidas; se vires algo importante fora do âmbito, anota em `NOTAS.md` e continua.
- Uma tarefa de cada vez: planeia (lista curta de passos e ficheiros a tocar), executa, verifica, e só depois passa à seguinte.
- Antes de mexer num ficheiro partilhado (`pubspec.yaml`, `lib/main.dart`, router, esquema drift, `supabase/migrations`), diz em uma linha o impacto.

**Poupar tokens**
- Consulta primeiro o grafo do graphify; abre só os ficheiros que ele indicar e, em ficheiros grandes, só as linhas necessárias. Nunca leias pastas inteiras, `build/`, `.dart_tool/`, ficheiros gerados (`*.g.dart`, `*.freezed.dart`) ou `pubspec.lock` sem motivo.
- Usa `rg`/pesquisa em vez de ler ficheiros para "ver o que há".
- Não repitas código nem ficheiros na resposta; mostra só o diff ou o caminho e a linha.
- Respostas curtas: o que mudou, o resultado da verificação, o que falta. Sem resumos do que já foi dito.
- Corre comandos com saída filtrada (`flutter test --reporter compact`, `| tail -40`).

**Sem alucinações**
- Não inventes APIs, parâmetros, nomes de pacotes, versões, tabelas ou colunas. Confirma no código, no `pubspec.lock`, na documentação oficial (pub.dev, Supabase docs) ou no esquema real (`list_tables` do MCP Supabase) antes de usar.
- Se não sabes, diz "não confirmei" e verifica; não adivinhes.
- Nunca dês uma tarefa por feita sem prova: `dart format --set-exit-if-changed .`, `flutter analyze` sem avisos e `flutter test` verdes, mais o portão da fase. Mostra o resultado real dos comandos.
- Pacote novo só se a fase o nomear; confirma licença e suporte web antes de o adicionar.

**Ferramentas disponíveis (usa-as em vez de improvisar)**
- Claude Code: skills `flutter:*` (arquitetura, Riverpod, drift, testes, async, acessibilidade, i18n), `dart-flutter:*` (análise estática, testes, conflitos de pacotes) e `flutter-skills:*` (gerar ecrãs, providers, modelos, testes). Carrega só a skill que a tarefa precisa.
- MCP Supabase: esquema, migrações, logs e advisors (corre `get_advisors` depois de cada migração). Nunca alteres o projeto de produção sem pedido explícito; usa migrações em `supabase/migrations`.
- MCP Dart/Flutter (quando ligado): análise, erros em tempo de execução, hot reload.
- Antigravity: usa o planeamento (Planning) para tarefas com vários ficheiros e o modo rápido (Fast) para mudanças pequenas; verifica no browser/emulador integrado quando houver interface.
- Modelos: o mais forte (Opus) planeia e revê; o mais rápido (Sonnet) executa o plano. Não reabras decisões já tomadas no prompt da fase.

**Qualidade não se negocia**
- Segue as regras do prompt da fase (dropdowns em vez de chips, menu "⋮", paleta, repositórios abstratos, UUID e `atualizadoEm`, RLS por `user_id`).
- Cada lógica nova leva teste; nenhum teste é apagado, saltado ou enfraquecido para ficar verde.
- No fim da tarefa: commit pequeno com mensagem clara, e uma linha com o que ficou por fazer.
