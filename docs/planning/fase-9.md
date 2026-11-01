# Fase 9 · Correções (cópia JSON, importações, limites de tempo, CI)

**Estado:** plano aprovado a 2026-11-01, com as decisões D1–D6. Só Dart e CI: sem migração SQL e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** corrigir os erros confirmados na revisão do código de 2026-11-01, antes do P1 da comparação de preços.

## 0. Contexto e decisões

### 0.1 O que existe (confirmado no código, 2026-11-01)
- `LocalLojasRepository.eliminar` (`lib/data/local/repositorios_locais.dart`): só deixa eliminar uma loja sem compras; apaga os `itens_lista` da loja, mas **não** os `aliases` nem os `registos_preco`.
- `montarExportacao` (`lib/import/exportar.dart`): as lojas apagadas não entram na cópia, e `slug(lojaId)` devolve o UUID quando a loja não existe. Um preço ou alias de uma loja eliminada sai com o UUID, e `_validarReferencias` (`lib/import/seed_modelo.dart`) recusa a cópia ("Preço refere … que não existe"). Na prática, a cópia de segurança deixa de poder ser restaurada.
- Ainda em `montarExportacao`, as contagens `controlo.aliases` e `controlo.itens_lista` não usam as listas filtradas. Isto não tem efeito: `verificarControlo` só compara os totais em cêntimos.
- Importações em `importar_exportar_page.dart` (`_gravarTaloes`, `_gravarLote`, `_importarJson`): primeiro a RPC, depois o `recarregarTudo()` e, nos talões, os aliases, tudo no mesmo `try`. Qualquer erro mostra "A importação falhou e nada foi alterado", mesmo quando a RPC já gravou.
  - O `loteDosTaloes` gera ids novos a cada toque, por isso voltar a tocar em "Importar" depois de uma falha parcial duplica as compras.
  - O `Sincronizador._volta` apanha todos os erros, por isso o `recarregarTudo()` quase nunca lança. O `guardarAlias` só escreve na base local e na fila, por isso os aliases não se perdem sem rede.
  - Ao abrir os mesmos talões outra vez, o `_prepararTaloes` marca-os como "Já importado" (`comprasExistentes`).
- Limites de tempo: há limite em `SupabaseEstatisticasRepository` (10 s) e em `ServidorSupabase` (20 s). Não há limite em `SupabaseConsultasCompras`, em `SupabaseDadosRepository` nem em `buscarTudo` (`lib/data/supabase/`). O `.timeout()` só faz o cliente deixar de esperar: o pedido continua e o Postgres acaba a transação.
- Erros de rede nas leituras: o `SupabaseConsultasCompras._comRede` transforma qualquer erro que não seja `ErroDados` em "Sem rede". As leituras do `SupabaseDadosRepository` (`temDados`, `lerTudo`, `resumoPorLoja`, `resumoDados`, `comprasExistentes`) só usam o `comErrosTraduzidos`, e o `traduzirErro` deixa passar em cru o `TimeoutException` e os erros de rede (por exemplo, o `ClientException`).
- `ImportadorSeed.importar` (`lib/import/importar_seed.dart`) faz primeiro a RPC `dados.importar` e logo a seguir a leitura `dados.resumoPorLoja()`. Se a leitura falhar, lança depois de a cópia já estar gravada.
- `Sincronizador.recarregarTudo` corre o `base.limparCache()` (apaga os `registos` e os cursores e painéis guardados) antes do `sincronizar()`. Se a rede cair entre a resposta da RPC e o `puxar()`, a cache fica vazia (salvo o que está na fila) até à próxima tentativa automática ou até a rede voltar.
- CI: o `deploy-web.yml` publica no GitHub Pages sem correr `flutter analyze` nem `flutter test` (só o `build-apk.yml` corre os dois).
- Router (`lib/core/router.dart`): a app abre em `/lista` (`initialLocation`, redirect depois da entrada, rota `/`), mas o Painel está em primeiro no menu desde a Fase 4.
- Cores da web: `web/manifest.json` e as chaves `web:` do `pubspec.yaml` ainda têm a paleta antiga (`#B4532A`, `#FAF6F0`). As cores do tema azul são `Cores.azul` (`#0B57D0`) e `Cores.fundo` (`#FFFFFF`).

### 0.2 Decisões
| # | Decisão |
|---|---|
| D1 | Eliminar uma loja apaga também os seus `aliases` e todos os `registos_preco` dela, de todas as origens. A exportação ignora os órfãos que já existem, filtrando `aliases`, `listas` e `precos` pelas lojas ativas. |
| D2 | Quando a RPC de escrita responde com êxito, os dados contam como gravados: a pré-visualização fecha e o resumo é atualizado logo a seguir. Um erro depois disso mostra "Os dados foram gravados, mas …", e nunca "nada foi alterado". |
| D3 | Limites de tempo: 10 s nas leituras curtas (`contarCompras`, `comprasDaLoja`, `locaisUsados`, `temDados`, `resumoPorLoja`, `resumoDados`) e em cada página do `buscarTudo`; 60 s nas RPCs de escrita (`importar`, `importarLote`, `apagarTudo`). |
| D4 | Quando uma escrita passa do tempo, aparece "O servidor não respondeu a tempo; a operação pode ter ficado gravada. Confirma no resumo antes de repetir." e a pré-visualização fecha. Para a interface o distinguir, há um erro próprio, `ErroSemResposta`, subclasse de `ErroDados` em `lib/data/repositorios.dart`. |
| D5 | A app abre no Painel (`/painel`), em linha com a ordem do menu. |
| D6 | Ficam fora desta fase, registadas em `notas.md`: a keystore própria para o release (hoje o APK do CI tem uma chave debug diferente da local, e o `adb install -r` não o instala por cima) e a cor do ícone adaptativo (`#FAF6F0`), que depende do desenho de `assets/icon/`. |

## T1 · Cópia JSON com loja eliminada [x]
- Primeiro, um teste que reproduz o erro e falha: numa loja sem compras, com um preço manual e um alias, eliminar a loja, correr `montarExportacao` e ler o resultado com `SeedFicheiro.lerTexto`. Hoje é recusado.
- `LocalLojasRepository.eliminar`: apagar também os `aliases` (`chaveDe('aliases', …)`) e os `registos_preco` da loja, como já faz com os `itens_lista`.
- `montarExportacao`: um conjunto `lojasAtivas` que filtra `aliases`, `listas` e `precos`. O `controlo.aliases` e o `controlo.itens_lista` passam a contar as listas filtradas.
- Um teste para os órfãos que já existem: um preço com `loja_id` de uma loja apagada não entra na cópia, e a cópia é aceite.

## T2 · Limites de tempo nos pedidos ao Supabase [x]
- `ErroSemResposta` (D4) em `lib/data/repositorios.dart`.
- Os limites da D3, no mesmo padrão de `supabase_estatisticas.dart` (`.timeout(limite)` dentro de `comErrosTraduzidos`).
  - Nas leituras dos dois repositórios, um `TimeoutException` ou um erro de rede passa a "sem rede", como no `_comRede`. As leituras do `SupabaseDadosRepository` passam a usar o mesmo auxiliar. O `_comRede` sai do `SupabaseConsultasCompras` e vai para `base.dart`, com a mensagem como parâmetro.
  - Nas escritas, um `TimeoutException` passa a `ErroSemResposta`.
- Teste: um pedido que nunca responde, com um limite curto injetado, dá `ErroSemResposta` na escrita e "sem rede" na leitura. Um pedido que lança um erro de rede, na leitura, dá "sem rede".

## T3 · Importações: mensagens certas e sem duplicar [ ]
- Em `_gravarTaloes`, `_gravarLote` e `_importarJson`, separar a RPC do que vem depois (D2):
  - RPC com êxito → fechar a pré-visualização, `_versaoResumo++`, e só então `recarregarTudo()` e os aliases;
  - erro depois da RPC → "Os dados foram gravados, mas …";
  - `ErroSemResposta` → a mensagem da D4 e a pré-visualização fecha;
  - outro erro na RPC → mantém "A importação falhou e nada foi alterado" (as RPCs são transacionais).
- Testes de widget com fakes:
  - `importarLote` com êxito e `recarregarTudo` a lançar → mensagem "gravados" e a pré-visualização fechada;
  - `importarLote` a lançar `ErroSemResposta` → a mensagem da D4 e a pré-visualização fechada;
  - `importarLote` a lançar `ErroDados` → "nada foi alterado" e a pré-visualização continua aberta.
- `_importarJson`: no `ImportadorSeed.importar`, a leitura `resumoPorLoja()` passa a contar como pós-gravação (D2).
  - Se falhar, o resultado volta sem a verificação por loja (`ResultadoImportacao.lojas` passa a aceitar `null`, que quer dizer "verificação não feita").
  - O ecrã mostra "Cópia gravada; não foi possível verificar os totais por loja. Vê o resumo mais tarde."
  - Teste no `ImportadorSeed`: a RPC com êxito e `resumoPorLoja` a lançar → resultado com as contagens e `lojas == null`, sem exceção.
- O mesmo tratamento no "Apagar todos os dados" (`apagarTudo`): com `ErroSemResposta`, a mensagem da D4.

## T4 · CI: verificar antes de publicar a web [ ]
- `deploy-web.yml`: `flutter analyze` e `flutter test` antes do `flutter build web`, como no `build-apk.yml`.

## T5 · Abrir no Painel [ ]
- `lib/core/router.dart`: `initialLocation`, o redirect depois da entrada e a rota `/` passam para `/painel`.
- Teste: com sessão, a app abre no Painel; sem sessão, vai para `/entrar`; depois de entrar, vai para o Painel.

## T6 · Cores da web [ ]
- `web/manifest.json` e as chaves `web:` do `pubspec.yaml`: `theme_color` `#0B57D0` e `background_color` `#FFFFFF`. Ver se o `web/index.html` tem alguma `theme-color` antiga.
- Não mexer no `adaptive_icon_background` nem no `colors.xml` (D6).

## T7 · Documentação [ ]
- `notas.md`: a keystore própria e a cor do ícone (D6). Também como comportamento conhecido: se a rede cair a meio do `recarregarTudo()`, a cache fica vazia até à próxima tentativa (ver 0.1).
- `sincronizacao.md`: os limites de tempo (D3) e a regra da D4.
- `mapa.md`: o `ErroSemResposta`.
- `ESTADO.md` e este plano marcados.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes.
- No telemóvel (`adb install -r`) e na web, em claro e escuro, abaixo e acima de 800 px:
  - a app abre no Painel;
  - eliminar uma loja de teste com um preço manual, exportar a cópia JSON e validá-la (sem `substituir`);
  - importar talões e ver a mensagem e a pré-visualização fechada.
- Sem migrações: os advisors não mudam.
