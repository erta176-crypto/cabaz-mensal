# Fase 1B · Importar e exportar

**Estado:** implementada, à espera do portão.

# Cabaz Mensal · Fase 1B (Importar e exportar ficheiros) · Plano

## Contexto
A 1A está fechada (com os números do histórico confirmados). Hoje "Importar e exportar" só trata a cópia JSON. A 1B acrescenta:
- **importar** artigos e preços, compras e linhas, e listas, em CSV e XLSX, sempre com pré-visualização. Inclui o CSV da app antiga "Lista de Compras";
- **exportar** em XLSX, CSV, PDF e TXT;
- **arrastar e largar** no PC.

O que for exportado em CSV ou Excel tem de voltar a entrar sem alterações.

Este plano substitui o anterior da 1B e segue as regras novas do prompt: índices únicos completos, reativar a mesma linha, `public.` nas funções SQL, CSV da app antiga e TXT com emojis.

Também acerto dois pendentes da 1A:
- o rodapé da Lista no ecrã largo;
- a sincronização, que volta a puxar ~3 400 linhas por minuto.

## 0. Correções da 1A (primeiro)
Verifiquei no servidor que não há lojas, categorias nem artigos com nomes repetidos, e que existem os índices parciais `lojas_user_id_slug_ativas` e `categorias_user_id_nome_ativas`.

**Migração `20261018000000_fase1b.sql`:**
- tirar os dois índices parciais e repor `unique (user_id, slug)` em lojas e `unique (user_id, nome)` em categorias;
- criar a RPC `public.importar_lote(payload jsonb)` (secção 2);
- criar a função `public.agora()`, que devolve o `now()` do servidor.

**Reativar em vez de duplicar:**
- **Lojas e categorias:** a app já reativa a mesma linha (mesmo id) ao criar com o nome de uma apagada (`LocalLojasRepository.guardar` e `LocalCategoriasRepository.criar`, em `lib/data/local/repositorios_locais.dart`). Com o índice completo, o upsert por id cai na mesma linha. Não muda nada no Dart.
- **Artigos** (`lib/features/lista/adicionar_artigo.dart`, `_criar`): hoje criar um artigo com o nome de um apagado gera um id novo. Passa a procurar, na cache e incluindo os apagados, um artigo com o mesmo nome normalizado, e reativa-o com o mesmo id (`apagado_em = null` e campos atualizados). Para isso, `LocalArtigosRepository` ganha `procurarPorNome(nome, {incluirApagados})`.
- **Itens da lista:** já sincronizam pela chave natural (`loja_id`, `artigo_id`) sem enviar o id, por isso a mesma linha mantém o mesmo id. Já há um teste que o confirma (`test/sync/sincronizacao_test.dart`, "voltar a juntar um item apagado reativa-o").

**Sincronização mais leve** (`lib/data/sync/sincronizador.dart`, `servidor_supabase.dart`, `servidor.dart`):
- antes de puxar, a app pergunta a hora ao servidor (`agora()`);
- o cursor guardado passa a ser o maior entre o `atualizado_em` mais recente e essa hora menos a margem. Assim, as linhas importadas há horas não voltam a ser puxadas a cada minuto;
- o servidor falso de teste ganha `agora()`.

**Rodapé da Lista** (`lib/features/lista/lista_page.dart`, `_Rodape`): centrado e com no máximo 960 px, alinhado com a lista.

## 1. Pacotes novos (Dart puro, Android e web)

| Pacote | Licença | Para quê |
|---|---|---|
| `excel` 4.0.x | MIT | ler e escrever .xlsx |
| `csv` 8.0.x | MIT | ler e escrever CSV |
| `pdf` 3.13.x | Apache-2.0 | gerar o PDF da lista e da tabela de preços |

- Sem syncfusion e sem `printing`: o PDF é gerado em bytes e sai pelo caminho de sempre (`core/ficheiros/guardar_ficheiro_*`), que descarrega na web e partilha no Android.
- Para o "€" e o "ç" no PDF, junto a letra Instrument Sans (licença OFL) em `assets/fonts/`.
- **Arrastar e largar:** feito à mão, com os eventos `dragover`/`drop` do browser via `package:web` (que já é dependência), por importação condicional. Os pacotes que existem para isto são plugins nativos.

## 2. Importar (`lib/import/`, testável sem interface)
- **`tabela_lida.dart`:**
  - CSV: retira o BOM e deteta o separador (`;` ou `,`) pelo cabeçalho;
  - XLSX: escolhe a folha e converte as células de número e de data.
- **`valores.dart`:** reaproveita `centDeTexto` e `eurosParaCent` de `domain/dinheiro.dart`. Acrescenta:
  - datas dd/mm/aaaa e aaaa-mm-dd ("31/02/2026" dá erro);
  - números do Excel → cêntimos com `(v * 100).round()`;
  - quantidade em texto livre: "2", "1,5 kg" → 1,5 + kg, e "2 pacotes" → 2.
- **`campos.dart`:** os campos de cada tipo e o palpite pelo cabeçalho, comparado sem acentos (por exemplo "PVP"/"Preço" → Preço, "Secção"/"Categoria" → Categoria, desconhecido → Ignorar).
- **Análise** (`analisar_artigos.dart`, `analisar_compras.dart`, `analisar_lista.dart`): cada linha fica Novo, Atualiza, Já existe, Erro (com o motivo) ou Ignorada. Há um resumo ("214 linhas: 180 novas, 32 atualizam, 2 com erro").
- **Artigos:**
  - encontrados pelo nome normalizado (`domain/texto.dart`) ou por alias;
  - menu "Se o artigo já existir": Atualizar preço e categoria / Manter o que existe;
  - categorias novas são criadas;
  - cada preço importado cria um registo com origem 'manual'.
- **Compras:**
  - agrupadas por loja + data + local;
  - se o ficheiro tiver a coluna "Compra", é ela que separa os talões; se tiver "Total da compra", entra também na chave do grupo;
  - quando não dá para separar, o grupo leva o aviso "Possíveis talões juntos". Há 12 casos destes no histórico, e todos se separam pelo total;
  - uma compra com a mesma loja, data e total de uma existente fica "Já existe". As existentes são lidas do servidor;
  - se a soma das linhas não bater com o total, a compra fica com `rever = true`.
- **Lista:** junta os artigos à lista da loja indicada, reativando os que lá estavam. Os artigos que não existem são criados.
- **CSV da app antiga** "Lista de Compras" (PWA): reconhecido pelo cabeçalho `Categoria;Artigo;Comprado;Quantidade;Supermercado`, com separador `;` ou `,`.
  - Supermercado → Loja. Quando está vazio, usa o menu "Loja para linhas sem supermercado".
  - Quantidade em texto livre; sem número, usa a quantidade habitual do artigo.
  - Comprado "Sim" → comprado.
  - As linhas sem quantidade ficam "Ignoradas", com a opção "Importar também os artigos sem quantidade para o catálogo".
- **`lote.dart` → RPC `public.importar_lote(payload)`:** security invoker, `search_path` vazio, `public.` em todas as tabelas, numa só transação.
  - Insere categorias e artigos novos e reativa os apagados (upsert pelo id, com `apagado_em = null`).
  - Atualiza categorias e preços.
  - Insere compras e linhas (`on conflict (id) do nothing`).
  - Faz upsert dos itens de lista pela chave natural, com `apagado_em = null`.
  - Os ids são gerados no cliente e a função devolve as contagens.
  - Testo-a no SQL Editor (por `execute_sql`, com um utilizador simulado e `rollback`) antes de a usar na app.
- **Sem rede:** em todos os tipos, incluindo o JSON, o botão "Importar N linhas" fica desativado, com a explicação. A pré-visualização de artigos e de lista funciona a partir da cópia local.

## 3. Exportar (`lib/export/`)
- **Menus:**
  - O que exportar: Compras e linhas, Artigos e preços, Lista do mês, Cópia completa;
  - Período (só para compras): Este mês, Últimos 12 meses, Todo o histórico;
  - Loja: Todas ou cada loja;
  - Formato: só os que valem para o tipo escolhido.
- **Formatos:**
  - XLSX: uma folha por tabela, cabeçalhos em português, números como números;
  - CSV: `;`, vírgula decimal e BOM UTF-8;
  - PDF: lista para imprimir e tabela de preços;
  - TXT: a lista;
  - JSON: a cópia v2, que já existe.
- **Colunas pensadas para a ida e volta:**
  - artigos: `Artigo · Categoria · Unidade · Loja · Preço`, uma linha por artigo × loja;
  - compras: `Compra · Data · Loja · Local · Artigo · Texto do talão · Quantidade · Peso (kg) · Preço unitário · Bruto · Desconto · Pago · Total da compra`;
  - lista: `Loja · Categoria · Artigo · Quantidade · Unidade · Comprado`.
- **TXT da lista** (`escrever_txt.dart`; substitui o `listaEmTexto` da 1A, que passa a usar este formato na partilha):
  - título "🛒 Lista de compras · <loja> · <data>";
  - um bloco por categoria com o emoji escolhido por palavra-chave no nome normalizado da categoria (a tabela do prompt; sem correspondência, 🛍️);
  - linhas "• Artigo — 2 kg", com " (Lidl)" só em "Todas as lojas";
  - os artigos já comprados não entram.
- **Nome do ficheiro** com a data, por exemplo `cabaz-artigos-2026-10-20.xlsx`. Na web descarrega; no Android abre a partilha.
- **Lista:** a partilha passa a oferecer também PDF.

## 4. Ecrã "Importar e exportar" (`lib/features/importar_exportar/`)
- **Cartão Importar:** menus "O que importar", "Formato" e "Folha" (quando há várias) e o botão "Escolher ficheiro". No PC (≥ 800 px) há também uma zona para largar o ficheiro.
- **Pré-visualização:**
  - um menu por coluna (campo da app ou Ignorar);
  - os menus "Se o artigo já existir" e "Loja para linhas sem supermercado";
  - a tabela de linhas com o estado e o motivo, que rola na horizontal no telemóvel;
  - o resumo e o botão "Importar N linhas";
  - mudar um menu recalcula logo.
- **Depois de gravar:** `sync.recarregarTudo()` e o Resumo dos dados atualiza-se.

## 5. Testes (flutter test, sem rede)
- **CSV:** com `;` e com `,`, vírgula decimal, aspas e BOM.
- **XLSX:** cabeçalhos em português, células de número e de data.
- **Datas:** nos dois formatos; uma data inválida dá erro.
- **Cêntimos:** "1,29" → 129, "0,1" + "0,2" → 30, número do Excel 1.29 → 129.
- **Colunas:** palpite pelo cabeçalho; linhas com erro (preço inválido, artigo vazio).
- **Artigos:** Novo, Atualiza e Já existe; "Manter o que existe"; alias sem acentos.
- **Compras:** "Já existe"; o caso dos dois talões no mesmo dia e local, separado pelo total, e o aviso quando não dá para separar.
- **Ida e volta:** exportar e voltar a importar dá zero alterações, em CSV e em XLSX, para artigos, compras e lista.
- **Portão simulado:** 2 preços alterados e 1 artigo novo → "2 atualiza, 1 novo".
- **Reativação:**
  - um item da lista apagado volta na mesma linha, com o mesmo id e `apagado_em = null`, sem erro de chave duplicada (o teste já existe);
  - um artigo apagado volta com o mesmo id (teste novo).
- **CSV da app antiga:** reconhecido pelo cabeçalho; "1,5 kg" → 1,5 + kg; linhas sem quantidade ignoradas; Comprado "Sim" → comprado.
- **TXT:** emoji certo por categoria, incluindo 🛍️; os comprados ficam de fora.
- **PDF:** começa por `%PDF` e tem "€" e "ç".
- **Sincronização:** o cursor com `agora()` não volta a puxar dados antigos e ainda apanha uma escrita lenta dentro da margem.
- **Sem rede:** teste de widgets em que o botão Importar fica desativado.

## Verificação
1. `flutter analyze` sem avisos; `flutter test` verde; `flutter build web` e `flutter build apk` compilam.
2. Depois de aplicares a migração no SQL Editor:
   - testo a RPC no servidor (com `rollback`) e verifico os índices completos;
   - corro os advisors;
   - confirmo que os números do histórico se mantêm.
3. **Portão da 1B**, contigo, com cada passo confirmado por SQL:
   - Excel editado → "2 atualiza, 1 novo";
   - CSV de compras reimportado → tudo "Já existe";
   - lista em PDF e em TXT partilhada no WhatsApp;
   - cópia JSON → Apagar tudo → importar → mesmos números.
4. No fim: `graphify update .` e atualização de `docs/architecture/mapa.md`.
5. Push só depois do portão; depois confirmo as Actions e a web publicada.

## Desvios ao prompt
- **Arrastar e largar feito à mão** com `package:web`, porque os pacotes que existem são plugins nativos.
- **Uma só RPC `importar_lote`** para os três tipos: a mesma transação, menos SQL, e o lote é testado em Dart.
- **XLSX de compras com uma folha "Compras" de resumo**, que a importação ignora.
- **Coluna "Compra"** como chave opcional para separar talões. Sem ela, o agrupamento é por loja + data + local, como diz o prompt, com o desempate pelo total.

## Commits
Por esta ordem: correções da 1A e migração, pacotes e letra do PDF, importação, exportação e TXT, ecrã, testes. Os commits incluem só ficheiros do projeto: as alterações do graphify já preparadas (`.claude/`, `.codex/`, `AGENTS.md`) ficam de fora até decidires. Push só depois do portão.
