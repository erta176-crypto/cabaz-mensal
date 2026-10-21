# Mapa do código

*Atualizar quando mudarem pastas, ficheiros, tabelas ou funções. Para relações entre peças, usar o graphify.*

## `lib/domain/`: modelos e regras puras
- `dinheiro.dart`: dinheiro sempre em cêntimos inteiros e pesos em gramas.
- `texto.dart`: pesquisa sem acentos.
- `compra.dart`: cálculos de Concluir compra.
- `preferencias.dart`: preferências e gestos.

## `lib/data/`: a única pasta que fala com o Supabase e com o drift
- `repositorios.dart`: as interfaces.
- `providers.dart`: os providers Riverpod.
- `local/`: base drift genérica (tabela `registos` com JSON por linha, fila `pendentes`, `estado`) e os repositórios locais.
- `sync/`: a sincronização ([`sincronizacao.md`](sincronizacao.md)).
  - `escrita.dart`: grava na cache e põe na fila.
  - `sincronizador.dart`: envio e receção.
  - `servidor_supabase.dart`: a ligação ao Supabase.
- `supabase/`: autenticação, consultas de compras e dados (importar, exportar, apagar, resumo).

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
- `shell`: navegação com corte a 800 px e faixa de sincronização.
- `entrada`
- `lista`: Lista do mês e Concluir compra.
- `artigos`
- `importar_exportar`: pré-visualização e arrastar e largar na web.
- `definicoes`
- `em_breve`

## `supabase/migrations/`
- `fase0`: tabelas, RLS, `importar_seed`.
- `fase1a`: `apagado_em`, lista do mês, `preferencias`, `concluir_compra`.
- `fase1b`: índices únicos completos em lojas e categorias, `agora()`, `importar_lote`.

## `test/`
- Servidor falso em memória e drift em memória (`test/sync/`). Nenhum teste usa o Supabase real.
