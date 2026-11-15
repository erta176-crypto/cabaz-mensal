# Fase 9b · Correção: limite de tempo das leituras por páginas

**Estado:** concluída a 2026-11-15; falta o portão no telemóvel/web. Só Dart: sem migração SQL, sem pacotes novos, sem alterações de interface. Quem executa: Sonnet 5.5. Não reabrir as decisões abaixo.

**Objetivo:** a cópia JSON, a exportação de compras e a abertura de talões deixam de falhar com "Sem rede" quando o servidor responde, mas o total das páginas passa de 10 s.

## 0. Contexto e decisões

### 0.1 O erro (confirmado no código, 2026-11-15)
- `lerComRede` (`lib/data/supabase/base.dart`) aplica `f().timeout(limite)` à função inteira.
- `SupabaseDadosRepository._ler` (`lib/data/supabase/supabase_repositorios.dart`) passa sempre `limite: limiteLeitura` (10 s).
- `lerTudo()` lê 8 tabelas, cada uma por páginas (`buscarTudo`), tudo dentro de um só `_ler`. `comprasExistentes()` faz o mesmo com uma tabela.
- Resultado: além dos 10 s por página (certo, D3 da Fase 9), há 10 s para o conjunto (errado). Introduzido na T2 da Fase 9.
- Quem chama: `importar_exportar_page.dart` (`lerTudo` na cópia JSON e na exportação de compras; `comprasExistentes` em `_prepararTaloes` e na pré-visualização de ficheiros).

### 0.2 Decisões
| # | Decisão |
|---|---|
| D1 | Nas leituras por páginas (`lerTudo`, `comprasExistentes`) o limite é só por página. Não há limite para o conjunto. |
| D2 | As leituras curtas (`temDados`, `resumoPorLoja`, `resumoDados`) ficam como estão: 10 s para a função. |
| D3 | Os erros continuam a ser traduzidos da mesma forma: tempo esgotado numa página ou erro de rede → "Sem rede: …"; `ErroDados` passa tal e qual. |
| D4 | O pacote `http` é transitivo e não pode ser importado nos testes. Para testar sem `SupabaseClient`, o ciclo das páginas sai para uma função pura. |

### 0.3 Fora do âmbito (não tocar)
- `escreverComLimite`, `ErroSemResposta` e as mensagens das importações.
- `SupabaseConsultasCompras` e `supabase_estatisticas.dart`.
- Qualquer ficheiro em `lib/features/`.
- `android/`, `.github/` e `docs/planning/fase-10.md` (Fase 10, em curso, com alterações por commitar: não as incluir no commit).

## T1 · Teste que reproduz o erro [x]
Ficheiro: `test/limites_tempo_test.dart` (acrescentar; não alterar os testes que lá estão).

Primeiro, só o necessário para o teste compilar: criar em `base.dart` a função da T2 (`buscarPaginas`) e o parâmetro `limite` anulável da T3, **sem** mudar ainda o repositório. Depois escrever os testes e confirmar que o primeiro falha quando se usa o limite global (é o comportamento de hoje).

Testes (limite por página de 40 ms; cada página demora 25 ms):
1. **Reproduz o erro:** 3 páginas cheias mais uma última incompleta, dentro de `lerComRede(..., limite: 40 ms)` → hoje dá `ErroDados` "Sem rede". Este teste fica no ficheiro a documentar o comportamento do limite global (nome: "com limite global, várias páginas lentas dão sem rede").
2. **O comportamento certo:** as mesmas páginas dentro de `lerComRede(..., limite: null)` → devolve todas as linhas (3 × tamanho da página + as da última).
3. **Página que nunca responde,** com `limite: null` no conjunto e 40 ms por página → `ErroDados` com a mensagem `semRede` (D3).
4. **`ErroDados` lançado por uma página** passa tal e qual.

Para os testes não precisarem de 1000 linhas por página, `buscarPaginas` recebe o tamanho da página como parâmetro (ver T2); usar 2 nos testes.

## T2 · `buscarPaginas` em `base.dart` [x]
- Nova função pública, pura (sem Supabase):
  ```dart
  Future<List<Map<String, dynamic>>> buscarPaginas(
    Future<List<Map<String, dynamic>>> Function(int inicio, int fim) pagina, {
    Duration limite = limiteLeituraPadrao,
    int tamanho = _tamanhoPagina,
  })
  ```
  Contém o ciclo que hoje está em `buscarTudo`: pede `pagina(inicio, inicio + tamanho - 1).timeout(limite)`, junta, e acaba quando a página vem com menos de `tamanho` linhas.
- `buscarTudo` mantém a assinatura e passa a chamar `buscarPaginas`, com `pagina` a fazer `cliente.from(tabela).select(colunas).order(ordem).range(inicio, fim)`.
- Comentário de uma linha em `buscarPaginas`: o limite é por página.

## T3 · Limite do conjunto opcional [x]
- `lerComRede`: `limite` passa a `Duration?` (por omissão continua `limiteLeituraPadrao`). Com `null`, não aplica `.timeout()` à função; a tradução de erros fica igual.
- `SupabaseDadosRepository`: um segundo auxiliar privado ao lado do `_ler`, para as leituras por páginas, que chama `lerComRede` com `limite: null` e a mesma mensagem `semRede`. Nome: `_lerPorPaginas`.
- `lerTudo()` e `comprasExistentes()` passam a usar `_lerPorPaginas`. Continuam a passar `limite: limiteLeitura` ao `buscarTudo`.
- `temDados`, `resumoPorLoja` e `resumoDados` não mudam (D2).

## T4 · Verificação e documentação [x]
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos, `flutter test --reporter compact`: tudo verde. Mostrar a saída real. Hoje são 470 testes; passam a ser 474.
- `docs/architecture/sincronizacao.md`, secção "Limites de tempo": deixar explícito que `lerTudo` e `comprasExistentes` só têm limite por página.
- `docs/architecture/mapa.md`: acrescentar `buscarPaginas` à linha do `base.dart`.
- `docs/ESTADO.md`: uma linha em "Feito". Este plano com as tarefas marcadas.
- `graphify update .`
- Um commit, só com `lib/data/supabase/`, `test/limites_tempo_test.dart` e `docs/`. Mensagem em português. Sem push.

## Regras para quem executa
- Antes de editar `base.dart` e `supabase_repositorios.dart`, dizer numa linha o impacto segundo o grafo (`graphify explain "lerComRede"`, `graphify explain "buscarTudo"`).
- Alterações cirúrgicas: nada de renomear, reformatar ou "melhorar" código vizinho.
- Nenhum teste existente é apagado ou enfraquecido.
- Nunca correr `flutter test`, `flutter run` nem `flutter drive` com o telemóvel como destino.
- Se algo do plano não bater com o código, parar e perguntar; não improvisar.

## Portão
- Os três comandos verdes.
- No telemóvel ou na web: exportar a cópia JSON e abrir um talão (PDF ou fotografia) continuam a funcionar.
