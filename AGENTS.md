## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- graphify-out/ is local only (gitignored); rebuild it with `graphify update .`. Never commit it.

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
