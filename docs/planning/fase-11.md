# Fase 11 · Correções vistas no telemóvel (alias sem rede, talão E.Leclerc)

**Estado:** aprovado (2026-11-15); T1 e T2 feitas (falta reimportar no telemóvel). Só Dart. Sem migração SQL e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** corrigir dois erros vistos no telemóvel ao verificar a Fase 10, antes de retomar o P1.

## 0. O que se viu e o que está confirmado

### 0.1 "Guardar alias" fica com erro depois de uma falha de rede
- No telemóvel, "Alterações por enviar" mostra a alteração "Guardar alias" com erro: `Sessão: ClientException with SocketException: Failed host lookup: '…supabase.co'`, e o banner "1 alteração com erro".
- ~~Hipótese inicial: `classificarErro` tratava o erro como permanente logo à primeira.~~ Errada.
- Confirmado no `gotrue` 2.27.3 (`fetch.dart:188-190`): uma falha de rede num pedido de autenticação (incluindo a renovação da sessão) chega como `AuthRetryableFetchException` sem `statusCode`, e `classificarErro` já a tratava como transitória.
- Causa real: `Sincronizador.enviar` marcava como permanente qualquer erro transitório ao fim de `maxTentativas` (20). Com a espera até 60 s, cerca de 15 min sem rede bastavam. Reproduzido em teste (`aliases_sync_test.dart`).
- Correção aprovada (2026-11-15, opção B): `ErroSync.semRede`. As falhas sem rede não contam tentativa nem ficam permanentes; os transitórios do servidor (5xx) continuam com o limite de 20.
- Os aliases não se perdem: ficam na fila e na base local (`docs/planning/fase-9.md`, 0.1). O que falha é o reenvio automático.

### 0.2 Talão do E.Leclerc "Talão sem data"
- Importar o PDF "E.Leclerc - Talão do 07.11.2026.pdf" deu "0 talões · 1 não reconhecido: Talão sem data".
- Confirmado no código: `lerLeclerc` (`lib/import/taloes/leclerc.dart:48` e `:54`) lança "Talão sem data" quando não encontra a linha da caixa ou, depois dela, o ano nas duas linhas seguintes. Este talão é mais recente do que os usados para escrever o leitor (a decisão da Fase 5 diz que foi feito com poucos exemplos).
- Causa confirmada (2026-11-19, PDFs de 07.11 e 11.11): o texto do pdfrx traz espaços NBSP (U+00A0) e colunas alinhadas com vários espaços; as expressões do leitor esperam um espaço normal, por isso a linha "Caixa … AAAA-MM-DD HH:MM" não era reconhecida. O de 11.11 também não tem a coluna do IVA nem secções (o leitor já aceita).

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Uma falha de rede nunca marca uma alteração como permanente, mesmo vinda da renovação da sessão. Só conta como permanente o que o servidor recusa (RLS, chave repetida, referência inválida) ou um erro de sessão que não é de rede (palavra-passe, conta apagada). |
| D2 | As alterações que já ficaram com este erro voltam a ser tentadas ao carregar em "Tentar agora" (já existe). Não se cria migração de dados. |
| D3 | O talão real nunca entra no repositório (é público): o teste usa um talão fictício com a mesma estrutura. |

## T1 · Alias: falha de rede continua transitória [x] (2026-11-15)
- Classe confirmada: `AuthRetryableFetchException` sem `statusCode` (ver 0.1).
- Teste que falhava: 25 envios sem rede → o alias fica na fila sem erro e chega ao servidor quando a rede volta. Testes novos: o 503 continua a ficar com erro à 20.ª tentativa; `classificarErro` distingue sem rede de 5xx e de sessão recusada.
- Correção: `ErroSync.semRede` (`servidor.dart`), definido em `classificarErro` (ramo `AuthException` e ramo de rede) e respeitado em `Sincronizador.enviar`. O `ServidorFalso` marca "Sem rede" e "Resposta perdida" como `semRede` e tem `indisponivel` (503).
- Os testes existentes de `test/sync/` passam sem alterações.

## T2 · Leitor do E.Leclerc [x] (2026-11-19)
- Feito: teste fictício com NBSP (`lidl_leclerc_test.dart`, falhava com "Talão sem data"); `lerLeclerc` troca NBSP e espaços seguidos por um espaço antes de partir em linhas. Talões reais: E.Leclerc 3/3, Lidl 71/71, Pingo Doce 24/24; análise 98/98. Falta reimportar no telemóvel.
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
