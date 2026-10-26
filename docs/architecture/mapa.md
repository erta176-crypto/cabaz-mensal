# Mapa do código

*Atualizar quando mudarem pastas, ficheiros, tabelas ou funções. Para relações entre peças, usar o graphify.*

## `lib/domain/`: modelos e regras puras
- `dinheiro.dart`: dinheiro sempre em cêntimos inteiros e pesos em gramas.
- `texto.dart`: pesquisa sem acentos.
- `ean.dart`: `normalizarEan` (EAN-8/13, GTIN-14; UPC-A e GTIN-14 com 0 à frente → EAN-13; dígito de controlo GS1).
- `compra.dart`: cálculos de Concluir compra.
- `preferencias.dart`: preferências e gestos; `ModoTema` (Sistema/Claro/Escuro).
- `estatisticas.dart`: períodos e filtros do Painel, `DadosPainel` (resultado da RPC `painel`), `CompraResumo` (RPC `historico_compras`), `mesesCompletos`, `categoriasTopo`, `porMes`.

## `lib/data/`: a única pasta que fala com o Supabase e com o drift
- `repositorios.dart`: as interfaces.
- `providers.dart`: os providers Riverpod; `temaProvider` (tema deste aparelho, chave `tema` na tabela `estado`).
- `local/`: base drift genérica (tabela `registos` com JSON por linha, fila `pendentes`, `estado`) e os repositórios locais.
- `sync/`: a sincronização ([`sincronizacao.md`](sincronizacao.md)).
  - `escrita.dart`: grava na cache e põe na fila.
  - `sincronizador.dart`: envio e receção.
  - `servidor_supabase.dart`: a ligação ao Supabase.
- `supabase/`: autenticação, consultas de compras e dados (importar, exportar, apagar, resumo).
  - `supabase_estatisticas.dart`: RPC `painel` (com cache do último resultado na tabela `estado`, chave `painel:<período>:<loja|todas>`) e `historico_compras` e linhas de uma compra (só com rede). Cada pedido tem um limite de 10 s; esgotado, conta como sem rede (decidido no portão da Fase 2: no Android, sem ligação, o pedido podia ficar preso).

## `lib/import/`: importação sem interface, testável
- Cópia completa JSON (formato v2 do `cabaz-seed.json`): `seed_modelo.dart`, `importar_seed.dart`, `exportar.dart`.
- Ficheiros CSV e XLSX:
  - `tabela_lida.dart`: leitura;
  - `valores.dart`: datas e quantidades;
  - `campos.dart`: campos e palpite pelo cabeçalho; CSV da app antiga;
  - `analisar_artigos.dart`, `analisar_compras.dart`, `analisar_lista.dart`: estado por linha;
  - `previsualizacao.dart`: `Catalogo`, `LoteImportacao` → RPC `importar_lote`.

## `lib/export/`
- `dados_export.dart`: tabelas com as colunas da ida e volta.
- `tabela_export.dart`: CSV `;` + BOM, XLSX.
- `escrever_pdf.dart`: letra em `assets/fonts/`.
- `texto_lista.dart`: TXT com emojis, também usado na partilha da Lista.

## `lib/features/`: um diretório por ecrã
- `shell`: navegação com corte a 800 px e faixa de sincronização; `tema_controlos.dart` (botão sol/lua no menu lateral e menu Tema das Definições).
- `entrada`
- `lista`: Lista do mês e Concluir compra.
- `artigos`: Artigos, categorias e lojas; `ver_artigo.dart` (Ver artigo com preços por loja e evolução do preço, aberto a partir de Artigos, Lista, Painel e detalhe da compra).
- `importar_exportar`: pré-visualização e arrastar e largar na web.
- `definicoes`
- `painel`: Painel e estatísticas (filtros de período e loja, números, gráficos; aviso quando os dados vêm da cache).
- `historico`: Histórico só de consulta (filtros, pesquisa por artigo, alias, EAN ou texto do talão, lista por mês) e detalhe da compra (ao lado a partir de 800 px).
- `estatisticas`: componentes de gráficos partilhados pelo Painel e pelo Ver artigo (`corDaLoja`, `BarrasHorizontais` sem `fl_chart`, `GraficoMeses` e `GraficoPreco` com `fl_chart`).

## `supabase/migrations/`
- `fase0`: tabelas, RLS, `importar_seed`.
- `fase1a`: `apagado_em`, lista do mês, `preferencias`, `concluir_compra`.
- `fase1b`: índices únicos completos em lojas e categorias, `agora()`, `importar_lote`.
- `p0_ean`: `artigos.ean` (opcional, `check` de formato, índice não único), `precos_atuais.fonte`, `importar_seed` e `importar_lote` com `ean` (o lote não apaga um `ean` existente).
- `fase2`: RPC `painel` e `historico_compras` (só leitura, `security invoker`).

## `test/`
- Servidor falso em memória e drift em memória (`test/sync/`). Nenhum teste usa o Supabase real.
