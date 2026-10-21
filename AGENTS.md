# Cabaz Mensal · regras para agentes

App Flutter (Android + web no GitHub Pages) sobre Supabase para registar compras de supermercado. Responder sempre em português de Portugal, de forma direta, técnica e concisa.

Este ficheiro é a fonte única das regras. É lido pelo agente nativo do Antigravity e, através de `@AGENTS.md` no `CLAUDE.md`, pelo Claude Code.

## Prioridades
1. Correção e fiabilidade
2. Eficiência no desenvolvimento
3. Poupança de tokens e de contexto
4. Arquitetura simples, limpa e sustentável
5. Organização e legibilidade
6. Qualidade visual e experiência do utilizador
7. Desempenho e facilidade de manutenção

## Por onde começar
1. `docs/ESTADO.md`: fase atual, feito, pendente, decisões em aberto.
2. Graphify: o que existe no código e como se liga (ver secção Graphify).
3. Só depois, os ficheiros que estes indicarem. Mapa do código: `docs/architecture/mapa.md`.

## Fluxo de cada tarefa
Uma tarefa de cada vez: planear (lista curta de passos e ficheiros a tocar), executar, verificar, e só depois passar à seguinte.

1. Compreender o objetivo; ler `docs/ESTADO.md` e o plano da fase.
2. Consultar o graphify; abrir só os ficheiros e as linhas indicados.
3. Confirmar o estado real antes de assumir. Separar sempre: existe / confirmado / proposto / por decidir.
4. Decisão relevante → parar e perguntar (ver Decisões). Decisão trivial → seguir as convenções do projeto.
5. Implementar a solução mais simples e robusta (ver Código).
6. Validar (ver Verificação) e mostrar a saída real.
7. Correr `graphify update .` e confirmar que correu.
8. Atualizar `docs/` (ver Documentação).
9. Commit pequeno; uma linha com o que ficou por fazer.

## Decisões e aprovação
- O plano é aprovado por fase (`docs/planning/fase-N.md`). Dentro do plano aprovado, cada tarefa avança sem pedir aprovação.
- Parar e perguntar quando houver ambiguidade ou mais de uma abordagem válida com impacto em arquitetura, dados, funcionalidade ou UX. Formato:
  - Opção A — … Vantagem: … Desvantagem: …
  - Opção B — … Vantagem: … Desvantagem: …
  - Recomendação: …
- Não reabrir decisões registadas em `docs/decisions/` nem no plano aprovado.

## Não inventar
- Não inventar APIs, parâmetros, pacotes, versões, ficheiros, tabelas, colunas, estados da app nem decisões. Confirmar no código, no `pubspec.lock`, na documentação oficial (pub.dev, Supabase) ou no esquema real da base de dados.
- Se não está confirmado, dizer "não confirmei" e verificar; não adivinhar.
- Nenhuma tarefa está feita sem prova (ver Verificação).

## Código
- Código mínimo: sem abstrações para um só uso, sem configurabilidade não pedida, sem tratamento de erros para cenários impossíveis. Exceção: as interfaces de repositório que o projeto já exige.
- Se existir uma solução mais simples do que a pedida, dizer antes de implementar.
- Alterações cirúrgicas: seguir o estilo existente; cada linha alterada liga-se ao pedido; remover só o que a própria alteração deixou órfão. Código morto antigo e tudo o que estiver fora do âmbito vai para `docs/planning/notas.md`.
- Bug: primeiro um teste que o reproduz (falha), depois a correção (passa).
- Cada lógica nova leva teste; nenhum teste é apagado, saltado ou enfraquecido para ficar verde.
- Pacote novo só se a fase o nomear; confirmar licença e suporte web antes de o adicionar.
- Regras do projeto: dinheiro em cêntimos inteiros e pesos em gramas; só `lib/data/` fala com o Supabase e o drift; repositórios abstratos; UUID e `atualizadoEm`; RLS por `user_id`; seguir as regras de UI do plano da fase (dropdowns em vez de chips, menu "⋮", paleta).
- Antes de alterar um ficheiro partilhado (`pubspec.yaml`, `lib/main.dart`, router, `lib/data/repositorios.dart` e implementações, `lib/data/providers.dart`, `lib/data/local/base_local.dart`, `lib/domain/`, `supabase/migrations/`), mostrar o impacto segundo o grafo, numa linha, antes de editar.

## UI/UX
- Reutilizar o tema e os componentes existentes antes de criar novos; manter consistência entre ecrãs.
- Verificar em claro e escuro, abaixo e acima do corte de 800 px, com `flutter run -d chrome` ou no emulador.
- Acessibilidade: semântica nos controlos, contraste, áreas de toque.

## Verificação
- `dart format --set-exit-if-changed .`
- `flutter analyze` sem avisos
- `flutter test --reporter compact`
- Portão da fase: ver `docs/testing/portoes.md`.

## Graphify
- Antes de qualquer `grep`, pesquisa ou leitura de ficheiros:
  - `graphify query "<pergunta>"` para perguntas gerais;
  - `graphify explain "<conceito>"` para uma classe, função ou tabela;
  - `graphify path "<A>" "<B>"` para a ligação entre duas peças.
- Pôr esta regra no prompt de qualquer subagente que explore código.
- Ficheiros de `graphify-out/` alterados depois de hooks ou atualizações são esperados e não são motivo para saltar o graphify. Só se salta se a tarefa for sobre o próprio grafo estar errado, ou se o utilizador o disser.
- O grafo está em `graphify-out/`, é só local (`.gitignore`) e só de código: `docs/` está excluído (decisão 0004). `graphify update .` só analisa o código, sem custo de API.
- `.graphifyignore` exclui `web/drift_worker.js`, `web/sqlite3.wasm`, `build/`, `dados-privados/`, `env/` e `docs/`.
- Limitação: os nós SQL não estão ligados ao Dart que os chama por texto (`rpc('concluir_compra')`, `from('itens_lista')`). Para impacto na base de dados, completar o grafo com uma pesquisa por esse nome no Dart.
- Se existir `graphify-out/wiki/index.md`, usá-lo para navegação geral.
- `graphify-out/GRAPH_REPORT.md` só para revisão geral da arquitetura, ou quando query/path/explain não chegarem.

## Documentação (`docs/`)
- Todo o Markdown de planeamento, arquitetura, decisões e testes vive em `docs/`. Na raiz ficam só `AGENTS.md`, `CLAUDE.md` e `README.md`.
- `docs/ESTADO.md`: curto; fase atual, feito, em curso, próximo, decisões em aberto. Aponta para os outros ficheiros, não os repete.
- `docs/planning/`: `fase-N.md` (plano aprovado, com as tarefas marcadas à medida que ficam feitas) e `notas.md` (fora do âmbito).
- `docs/architecture/`: `visao-geral.md`, `mapa.md` (pastas e ficheiros), `sincronizacao.md` (regras de sync).
- `docs/decisions/`: uma decisão por ficheiro, `NNNN-titulo.md`.
- `docs/testing/portoes.md`: verificação e portões.
- No fim de cada tarefa: atualizar `ESTADO.md` e marcar a tarefa no plano da fase. Decisão nova → ficheiro novo em `decisions/`. Pastas, ficheiros, tabelas, funções ou regras de sync novos → `mapa.md` ou `sincronizacao.md`.
- O repositório é público: nada de dados pessoais, chaves ou valores reais em `docs/`.

## Poupar tokens
- Nunca ler pastas inteiras, `build/`, `.dart_tool/`, ficheiros gerados (`*.g.dart`, `*.freezed.dart`) ou `pubspec.lock` sem motivo. Usar `rg` em vez de ler ficheiros para "ver o que há".
- Não repetir código nem ficheiros na resposta; mostrar só o diff ou o caminho e a linha.
- Respostas curtas: o que mudou, o resultado da verificação, o que falta. Sem resumos do que já foi dito.
- Comandos com saída filtrada (`flutter test --reporter compact`, `| tail -40`).

## Git, Supabase e dispositivos
- Commits pequenos em português. Push só depois de o utilizador confirmar o portão da fase.
- As migrações (`supabase/migrations/`) são aplicadas pelo utilizador no SQL Editor (decisão 0002). Depois, verificar no servidor (SQL e logs) e correr os advisors. Nunca alterar o projeto de produção sem pedido explícito.
- No telemóvel, instalar com `adb install -r` para não apagar os dados locais.
- Nunca commitar `dados-privados/` nem `env/`.

## Agente nativo do Antigravity
- Usar Planning para tarefas com vários ficheiros e Fast para mudanças pequenas.
- Não há hook automático: correr `graphify update .` no fim de cada tarefa que altere código.
