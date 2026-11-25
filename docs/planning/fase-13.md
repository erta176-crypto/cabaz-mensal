# Fase 13 · Categorias: renomear sem nomes repetidos, juntar e ver artigos

**Estado:** aprovado (2026-11-25); T1 e T2 feitas. Só Dart. Sem migração SQL e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** renomear uma categoria para um nome que já existe nunca chega ao servidor; o utilizador escolhe juntar as duas. Tocar numa categoria mostra os seus artigos.

Origem: prompt do utilizador de 2026-11-25 (o seu "P2"). Os outros dois pontos do prompt ficam para fases próprias: detalhe no Painel (Fase 14) e eliminar talão (Fase 15).

## 0. O que existe (confirmado)
- Servidor: `categorias_user_id_nome_key` = `UNIQUE (user_id, nome)`, sem filtro: inclui as apagadas e distingue maiúsculas (consulta a `pg_indexes`, 2026-11-25).
- `LocalCategoriasRepository.criar` (`repositorios_locais.dart:112`) recusa um nome igual de uma categoria ativa e reativa a apagada com o mesmo nome; a comparação é exata (`c['nome'] == nome`).
- `atualizar` (`:127`) não valida nada: renomear para um nome que existe vai para a fila e o servidor responde 409/23505. É a causa do "Alterar categoria" com erro.
- Renomear já existe: "⋮ → Editar" abre `DialogoCategoria` (`artigos_page.dart:118`).
- `eliminar(id, moverPara:)` move os artigos e marca `apagado_em` (`:134`); a UI pergunta para onde mover (`DialogoMoverArtigos`) e tem "Anular" (`_eliminarComAnular`).
- A lista de Artigos já filtra por categoria, com "Sem categoria" (`_filtroCategoria`, `artigos_page.dart:37`, `:264`, `:306`), com pesquisa e edição do artigo.
- Fila: o 23505 já é erro permanente ("Registo repetido", `servidor_supabase.dart:129`); fica com erro, a fila anda e só volta a ser enviado com "Tentar agora" (Fase 11, T1b). "Descartar e recarregar" já existe. Não há repetição sem fim.
- `normalizar` (`lib/domain/texto.dart:2`) tira acentos e passa a minúsculas.

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Nome igual = igual depois de `trim`, sem acentos e em minúsculas (`normalizar`), contra todas as categorias do utilizador, incluindo as apagadas. Vale para criar e renomear. Nome vazio é recusado. |
| D2 | Renomear para o nome de outra categoria ativa X: não grava; diálogo "Já existe a categoria X" com "Juntar a X" (move os artigos para X e elimina esta, com "Anular") ou "Cancelar". |
| D3 | Renomear para o nome de uma categoria apagada X: diálogo com "Recuperar X e juntar" (reativa X, move os artigos e elimina esta) ou "Cancelar". Recuperar sem juntar deixava as duas categorias, que não é o que o utilizador queria ao renomear. |
| D4 | Mudar só maiúsculas ou acentos da própria categoria ("leite" → "Leite") é permitido. |
| D5 | Tocar numa categoria mostra a lista de Artigos já filtrada por ela (reutiliza filtro, pesquisa e edição). Sem ecrã novo. |
| D6 | A fila não muda de comportamento (já não repete sozinha). Só a mensagem do 23505 fica legível: "Já existe um registo com o mesmo nome no servidor." e a ajuda "Descarta a alteração e volta a fazê-la." |

## T1 · Validação de nomes no repositório [x] (2026-11-25)
- Feito: `ErroNomeRepetido` (`repositorios.dart`), `_nomeLimpo` e `_comMesmoNome` em `LocalCategoriasRepository` (criar e atualizar), `juntar`. Testes em `test/sync/categorias_sync_test.dart` (10).
- O `ServidorFalso` ainda tinha o índice único parcial da 1A; passou a completo, como o real desde a 1B. Os testes existentes continuam a passar.
- Primeiro os testes que falham (`test/sync/` com o `ServidorFalso`, que passa a recusar nomes repetidos como o índice real): renomear para nome ativo (com outras maiúsculas e acentos) lança `ErroNomeRepetido` e nada vai para a fila; nome de categoria apagada idem, com a categoria apagada no erro; nome vazio recusado; só maiúsculas da própria passa.
- `criar` passa a usar a mesma comparação (D1).
- `CategoriasRepository` ganha `juntar(origemId, destinoId)`: reativa o destino se estiver apagado, move os artigos e elimina a origem. Testes: artigos movidos, origem apagada, destino reativado, e chega ao outro aparelho depois de sincronizar.
- Ficheiros partilhados (`repositorios.dart`, `repositorios_locais.dart`, `domain/`): dizer o impacto pelo grafo antes de editar.

## T2 · UI: juntar ou recuperar ao renomear [x] (2026-11-25)
- Feito: `DialogoJuntarCategoria` (`dialogos.dart`); `_juntarCategoria` em `artigos_page.dart` usa `_eliminarComAnular` (novo parâmetro `aviso`): a junção só é feita quando o aviso fecha sem "Anular". Criar com o nome de uma ativa continua a mostrar só a mensagem.
- Testes de widget em `test/categorias_page_test.dart` (5), com um repositório falso: a base drift real dentro do relógio falso do teste de widget prendia o `pumpAndSettle`. Os dados reais estão provados em `test/sync/categorias_sync_test.dart`.
- `artigos_page.dart`: ao apanhar `ErroNomeRepetido`, diálogo de D2/D3; "Juntar" usa `_eliminarComAnular` (o "Anular" repõe a origem e os artigos).
- Testes de widget: renomear para nome existente mostra "Juntar a X" e não grava; "Juntar" move e mostra "Anular".

## T3 · Tocar numa categoria abre os seus artigos [ ]
- O `ListTile` da categoria passa a ter `onTap`: muda para "Artigos" com `_filtroCategoria` = essa categoria. O "⋮" fica como está.
- Teste de widget: tocar na categoria mostra só os artigos dela.

## T4 · Mensagem do 23505 [ ]
- `servidor_supabase.dart`: texto de D6. Teste em `aliases_sync_test.dart` ou no teste de `classificarErro`.

## T5 · Documentação [ ]
- `sincronizacao.md` (regra do nome igual), `ESTADO.md`, este plano; `notas.md` se ficar algo de fora.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes.
- No telemóvel (`adb install -r`): renomear uma categoria para o nome de outra (com outras maiúsculas) oferece "Juntar"; juntar e anular; tocar numa categoria mostra os artigos; o "Alterar categoria" com erro que está na fila é descartado com "Descartar e recarregar".
