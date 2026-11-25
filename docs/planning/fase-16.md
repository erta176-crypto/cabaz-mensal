# Fase 16 · Leitor de talões do Intermarché (fotografia)

**Estado:** aprovado (2026-11-25). Só Dart; sem migração e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** importar talões em papel do Intermarché por fotografia, pelo mesmo caminho dos outros (OCR no aparelho → linhas → leitor → pré-visualização → `importar_lote`).

Origem: `notas.md` (2026-11-24: uma fotografia do Intermarché deu "Formato de talão não reconhecido").

## 0. O que existe (confirmado, 2026-11-25)
- Fotografias: `ler_fotos.dart` (OCR inteira e, se não bater, em faixas) → `linhasDasCaixas` → `normalizarOcr` → `lerTalao` (`ler_talao.dart`: Pingo Doce, Lidl, E.Leclerc, Mercadona; o primeiro que reconhece). OCR só no Android (ML Kit; decisão 0012).
- `TalaoLido`: loja, local, data, número, linhas, total, desconto da compra, linhas por reconhecer. `LinhaTalao`: texto, quantidade ou peso, preço unitário, bruto, desconto, secção. Não há campo para o código de barras.
- A loja do talão tem de existir no catálogo (`Catalogo.loja`: nome sem acentos ou slug); senão a pré-visualização diz "A loja … não existe; cria-a em Artigos". Hoje há 4 lojas; o Intermarché não existe.
- Provas com o OCR real: na Fase 7 foram tiradas com uma APK à parte (worktree, `applicationId` `.prova`, caixas em `dados-privados/ocr-prova/`); `test/taloes/fotos_reais_test.dart` lê essas caixas no PC (saltado sem a pasta). A prova não ficou no repositório. Nunca `flutter test`/`run`/`drive` no telemóvel (desinstala a app real).
- Exemplos em `dados-privados/talões/Intermarché/`: `IMG_20261121_102201.jpg` é do Intermarché (papel, câmara, 3072×4080, dobrado em dois sítios). `IMG_20260830_162348.jpg` é do **Mercadona** (igual à de `fotos/`): não conta como exemplo.

### 0.1 Estrutura do talão (vista na fotografia; os valores reais não entram no repositório)
- Cabeçalho: logótipo "Intermarché" (imagem estilizada), empresa do franchisado (nome varia de loja para loja), morada com código postal e localidade ("…NNNN-NNN LOCALIDADE"), "FATURA SIMPLIFICADA", "DOCUMENTO No:FS …".
- Colunas "ARTIGO(S) Preço IVA". Cada artigo: `*DESCRIÇÃO  EurN,NN L` (asterisco à frente, "Eur" colado ao valor, letra do IVA no fim).
- Artigo repetido: uma linha por unidade, seguidas, e depois uma linha `ART# 0NNNNNNNNNNNNN` (código de barras com 14 dígitos).
- Total: `N Art., COM TOTAL DE EurNN,NN` (letra grande); depois o pagamento (`MULTIBANCO EurNN,NN`, `TROCO`, `NUMERARIO`).
- "RECAPITULATIVO IVA" com uma linha por taxa e `TOTAL ilíquido IVA líquido`.
- Data e hora: `H:MM:SS  AAAA-MM-DD` (depois de "Certificado N° …"). Com cartão há também o bloco do terminal, com `AA-MM-DD`, "INTERMARCHE <LOCAL>" e `COMPRA NN,NNEur`.
- **Não visto** (um só exemplo): artigos ao peso, descontos e promoções, cartão de cliente, pagamento só em numerário (sem o bloco do terminal).

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Primeiro o OCR real: uma APK de prova à parte (worktree temporário, `applicationId` `pt.cabazmensal.app.prova`, `-t lib/main_prova.dart`, nada no `main`) lê a fotografia no telemóvel, inteira e em faixas, e grava as caixas em JSON; vêm para `dados-privados/ocr-prova/` com `adb pull`. Antes e depois, `pm list packages` confirma que `pt.cabazmensal.app` continua instalada. |
| D2 | Reconhecer o talão: o texto (sem acentos, minúsculas) tem "intermarch", ou tem "com total de" e "artigo(s)". Não depende do nome da empresa nem do bloco do terminal (pode não existir). O leitor fica em último lugar no `lerTalao`. |
| D3 | Artigo: `*DESCRIÇÃO EurN,NN L` (o asterisco e "Eur" opcionais, porque o OCR pode perdê-los ou trocá-los; a forma exata confirma-se no OCR real). Linhas `ART# …` não são artigos nem contam como "por reconhecer". Linhas iguais seguidas (mesmo texto e preço) juntam-se numa linha com quantidade N, como nos outros leitores. |
| D4 | Total: como no Mercadona (fase-7, D4). Candidatos: "COM TOTAL DE", a linha do pagamento, o `TOTAL` do recapitulativo (último valor) e `COMPRA` do terminal; fica o que bate com a soma das linhas; se nenhum bater, o "COM TOTAL DE" e o talão fica "a rever". |
| D5 | Data: `AAAA-MM-DD` da linha da hora; se faltar, `AA-MM-DD` do terminal. Número: o do "DOCUMENTO No:" (serve para os repetidos). Local: a localidade da linha do código postal, com maiúscula só no início de cada palavra ("Torres Novas"). |
| D6 | O código de barras do `ART#` não se usa nesta fase (a `LinhaTalao` não tem onde o guardar, e ligar artigos pelo EAN é outro trabalho): fica em `notas.md`. |
| D7 | A loja "Intermarché" é criada pelo utilizador em Artigos → Lojas antes de importar (é assim que as outras foram criadas). |
| D8 | O leitor é feito com um só talão: o que não se viu (0.1) fica a rever na pré-visualização, que já permite corrigir; os casos novos ficam em `notas.md` à espera de exemplos. |

## T1 · OCR real da fotografia (prova) [x] (2026-11-25)
- Feito: APK de prova num worktree temporário (`pt.cabazmensal.app.prova`, nome "Cabaz prova"). A pasta tem de ser criada pela própria app (`path_provider`, dependência indireta, só na prova): a criada pelo `adb` ficava sem acesso. O Xiaomi pede confirmação no ecrã para instalar uma app nova por USB. Prova desinstalada e worktree removido; `pt.cabazmensal.app` instalada antes e depois.
- Resultado: imagem inteira 83 caixas (3,5 s), em faixas 82 (2,3 s); caixas em `dados-privados/ocr-prova/` (fora do git).
- Estrutura do texto, depois de `linhasDasCaixas` e `normalizarOcr` (sem valores reais):
  - Logótipo lido como "IntermaRche" (inteira) e "Intermarche" (faixas); "INTERMARCHE <LOCAL>" no bloco do terminal.
  - Artigos numa linha: `*DESCRIÇÃO EurN,NN L`. O asterisco às vezes sai como "x" minúsculo colado ("xCHA…"). "Eur" sai sempre colado ao valor.
  - Repetidos seguidos, depois `ART# 0NNNNNNNNNNNNN`.
  - Total: `N Art., COM TOTAL DE EurNN,NN`; nas faixas "COM" saiu "0OM". Também `MULTIBANCO EurNN,NN`, `TOTAL a b c` no recapitulativo (num dos casos um valor com ponto) e `COMPRA NN,NNEur`.
  - Data: `H:MM:SS AAAA-MM-DD` (igual nas duas); terminal `AA-MM-DD HH:MM:SS`.
  - Número: `DOCUMENTO No:FS …`. Local: `… NNNN-NNN TORRES NOVAS`.
  - A soma dos artigos lidos bate com o total, inteira e em faixas.
- Conclusão: a normalização atual chega (não há regra nova); o leitor aceita o "x" no lugar do asterisco e procura o total por "TOTAL DE Eur" ou pelos outros candidatos (D4).
- Worktree temporário com a prova (D1); OCR da `IMG_20261121_102201.jpg`, inteira e em faixas; caixas em `dados-privados/ocr-prova/` (fora do git); tempos.
- No PC, passar as caixas por `linhasDasCaixas` e `normalizarOcr` e mostrar só a **estrutura** que o leitor precisa (sem valores nem nomes de artigos): como saem o asterisco, o "Eur", a letra do IVA, a linha do total e a data; se a imagem inteira chega ou se precisa de faixas.
- Se a normalização precisar de uma regra nova (ex.: "Eur 1,39" → "Eur1,39"), entra aqui, com teste, sem mudar os outros talões (`taloes_reais_test.dart` e `fotos_reais_test.dart` iguais).
- Remover o worktree e confirmar que a app real continua instalada.

## T2 · Leitor `lerIntermarche` [ ]
- Primeiro os testes, com um talão fictício com a mesma estrutura (`test/fixtures/taloes/intermarche_papel.txt`, valores e artigos inventados): hoje dá `null` ("Formato de talão não reconhecido").
- Testes: reconhecimento (D2) e que nenhum outro leitor o apanha; linhas, quantidades juntadas e `ART#` ignorado (D3); total que bate e total estragado (D4); data, número e local (D5); sem o bloco do terminal; uma linha estranha fica "por reconhecer".
- `lib/import/taloes/intermarche.dart` (novo) e `ler_talao.dart`.
- `fotos_reais_test.dart` passa a incluir a fotografia do Intermarché (lida e bate).

## T3 · Documentação [ ]
- `mapa.md` (leitor novo), `notas.md` (D6, D8, e retirar a nota do Intermarché), `ESTADO.md`, este plano.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes; `taloes_reais_test.dart` e `fotos_reais_test.dart` (locais) verdes.
- No telemóvel (`adb install -r`), depois de criar a loja "Intermarché": importar a fotografia pela galeria; aparece 1 talão "Novo" que bate (ou "a rever" com a diferença explicada), com a data e o local certos; importar; aparece no Histórico e no Painel.
