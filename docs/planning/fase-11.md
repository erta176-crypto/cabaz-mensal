# Fase 11 · Correções vistas no telemóvel (alias sem rede, talão E.Leclerc)

**Estado:** plano por aprovar (2026-11-15). Só Dart. Sem migração SQL e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** corrigir dois erros vistos no telemóvel ao verificar a Fase 10, antes de retomar o P1.

## 0. O que se viu e o que está confirmado

### 0.1 "Guardar alias" fica com erro depois de uma falha de rede
- No telemóvel, "Alterações por enviar" mostra a alteração "Guardar alias" com erro: `Sessão: ClientException with SocketException: Failed host lookup: '…supabase.co'`, e o banner "1 alteração com erro".
- Confirmado no código: `classificarErro` (`lib/data/sync/servidor_supabase.dart:114`) põe o prefixo `Sessão:` só nas `AuthException`, e só as trata como transitórias se forem `AuthRetryableFetchException`. Uma falha de DNS não é um erro do servidor: por isso o erro foi tratado como **permanente** logo à primeira (`Sincronizador.enviar`, linha 180) e a alteração deixou de ser tentada sozinha.
- **Não confirmei** qual é a classe exata que o `supabase_flutter` lança quando a renovação da sessão falha por falta de rede (pode ser uma `AuthException` simples ou uma `AuthUnknownException`). Confirmar no código do pacote em `pubspec.lock` (usar `read_package_uris` ou `rip_grep_packages`) antes de corrigir.
- Os aliases não se perdem: ficam na fila e na base local (`docs/planning/fase-9.md`, 0.1). O que falha é o reenvio automático.

### 0.2 Talão do E.Leclerc "Talão sem data"
- Importar o PDF "E.Leclerc - Talão do 07.11.2026.pdf" deu "0 talões · 1 não reconhecido: Talão sem data".
- Confirmado no código: `lerLeclerc` (`lib/import/taloes/leclerc.dart:48` e `:54`) lança "Talão sem data" quando não encontra a linha da caixa ou, depois dela, o ano nas duas linhas seguintes. Este talão é mais recente do que os usados para escrever o leitor (a decisão da Fase 5 diz que foi feito com poucos exemplos).
- **Não confirmei** o que difere neste talão: não tenho o texto extraído.

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Uma falha de rede nunca marca uma alteração como permanente, mesmo vinda da renovação da sessão. Só conta como permanente o que o servidor recusa (RLS, chave repetida, referência inválida) ou um erro de sessão que não é de rede (palavra-passe, conta apagada). |
| D2 | As alterações que já ficaram com este erro voltam a ser tentadas ao carregar em "Tentar agora" (já existe). Não se cria migração de dados. |
| D3 | O talão real nunca entra no repositório (é público): o teste usa um talão fictício com a mesma estrutura. |

## T1 · Alias: falha de rede continua transitória [ ]
- Confirmar a classe da exceção (0.1) e dizer qual é.
- Primeiro um teste que reproduz o erro e falha: `classificarErro` com a exceção de rede de uma renovação de sessão deve dar `transitorio: true`. Se for preciso, um teste do `Sincronizador` com um servidor falso que lança esse erro: a alteração fica na fila, sem erro, e é reenviada quando a rede volta.
- Correção em `classificarErro`, só no ramo das `AuthException`. Não mexer no resto.
- Verificar que os testes de sincronização existentes (`test/sync/`) continuam a passar sem alterações.

## T2 · Leitor do E.Leclerc [ ]
- Pedir ao utilizador que ponha o PDF em `dados-privados/talões/` (fora do git) e extrair o texto com a ferramenta do projeto que gera `test/fixtures/taloes/*.txt`.
- Mostrar só a diferença de estrutura que faz falhar a data (não colar valores reais nem nomes de artigos).
- Primeiro um teste com um talão fictício, com a mesma estrutura, que falha com "Talão sem data".
- Corrigir `lerLeclerc` para aceitar a variante, sem deixar de aceitar os talões atuais (os testes de `taloes_reais_test.dart` e as fixtures atuais têm de continuar iguais).
- Voltar a importar o PDF real no telemóvel.

## T3 · Documentação [ ]
- `notas.md`: o comportamento conhecido, se alguma das correções deixar casos fora.
- `sincronizacao.md`, se a regra de erros transitórios mudar.
- `ESTADO.md` e este plano marcados.

## Antes de começar (pendências da Fase 9b e 10)
- O portão da 9b ainda não está todo confirmado: falta exportar a cópia JSON e validá-la sem `substituir` (a abertura de talões já foi vista no telemóvel).
- Há 4 commits locais por enviar (plano e ícone da Fase 10, 9b, assinatura). O `git push` só depois de o utilizador confirmar o portão.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes.
- No telemóvel (`adb install -r`): o banner "1 alteração com erro" desaparece com "Tentar agora" e o alias fica enviado; o talão do E.Leclerc de 07.11.2026 importa.
