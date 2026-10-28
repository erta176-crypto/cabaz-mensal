# Fase 7 · Talões por fotografia (OCR)

**Estado:** aprovado a 2026-10-28 (revisto no mesmo dia, secção 0.4), com as decisões D1–D8. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** importar talões a partir de uma fotografia (câmara ou galeria, só no Android) das quatro lojas, com o mesmo caminho dos PDFs (Fase 5) e com correção das linhas na pré-visualização.

## 0. Contexto, provas e decisões

### 0.1 O que existe (confirmado no código, 2026-10-28)
- Talões em PDF: `texto_pdf.dart` (texto) → `lerTalao` (Pingo Doce, Lidl, E.Leclerc) → `analisarTaloes` (loja, repetidos, artigo de cada linha) → `PrevisualizacaoTaloes` → `loteDosTaloes` → RPC `importar_lote`.
- A pré-visualização só permite ligar a linha a um artigo, dar nome ou categoria; não permite mudar o texto, a quantidade ou o valor.
- As quatro lojas existem na base (`lojas`: E.Leclerc, Lidl, Mercadona, Pingo Doce). Não há leitor do Mercadona.
- Android: o manifesto só pede `INTERNET`; não declara `CAMERA` (o `image_picker` abre a câmara do sistema por intent, sem permissão).

### 0.2 Prova no telemóvel (2026-10-28, ramo temporário, nada no `main`)
OCR com `google_mlkit_text_recognition` 0.17.1 (modelo latino embutido, `com.google.mlkit:text-recognition:16.0.1`; sem rede) num Redmi com Android 15, às 3 imagens de `dados-privados/talões/fotos/`; resultado em `dados-privados/ocr-prova/` (fora do git). Depois, no PC, as caixas foram juntadas em linhas, normalizadas e passadas pelos leitores atuais.

| Imagem | Tipo | Imagem inteira | Em faixas (ampliadas 2×) |
|---|---|---|---|
| Mercadona | fotografia de papel, inclinada, com sombra | **bate**: 17/17 linhas, soma = total, data certa (~1,8 s) | 1 linha falha ("3.70" com ponto) (~18 s) |
| Lidl 1 | captura da app Lidl Plus, 720×≈5000 px | não reconhecido (letra pequena demais) | **bate**: 40 linhas, 0 por reconhecer (~10 s) |
| Lidl 2 | idem | não reconhecido | **bate**: 27 linhas, 0 por reconhecer (~9 s) |

Conclusões:
1. O ML Kit devolve a descrição e o preço em caixas separadas; juntar por altura (centro vertical, com a inclinação corrigida pelo ângulo mediano; tolerância de meia altura de linha) dá uma linha por artigo, igual à do PDF.
2. Com uma normalização pequena ("1, 09" → "1,09"; "2 X0,89" → "2 x 0,89"; "EUR/Kg" → "EUR/kg"; "3.70 D" → "3,70 D"), o **leitor do Lidl da Fase 5 serve sem alterações**.
3. Imagens altas com letra pequena (capturas) só se leem em faixas; uma fotografia normal lê-se melhor inteira.
4. Erros vistos: um dígito perdido no TOTAL do Mercadona (letra condensada), um espaço em falta ("1CÁP"), uma letra trocada ("MAÇĂ"). O total certo aparece noutras linhas do mesmo talão.
5. **Não confirmado:** Pingo Doce e E.Leclerc em papel (não há fotografias de exemplo; o leitor do Pingo Doce procura "Artigos"/"Resumo", que podem não existir no papel); artigos a peso no Mercadona (o exemplo não tem).

### 0.3 Pacotes (o plano nomeia-os; ambos resolvem sem mudar outras versões)
| Pacote | Versão | Licença | Editor | Uso |
|---|---|---|---|---|
| `google_mlkit_text_recognition` | 0.17.1 | MIT | flutter-ml.dev | OCR no aparelho (Android/iOS; sem web) |
| `image_picker` | 1.2.4 | BSD-3 / Apache-2.0 | flutter.dev | câmara e galeria |

O modelo embutido aumenta o APK; medir antes/depois no portão.

### 0.4 Revisão do plano (2026-10-28): o que se verificou e o que mudou
| Ponto | Verificação | Consequência no plano |
|---|---|---|
| A web compila com os dois pacotes? | `flutter build web` no ramo da prova, com os dois pacotes importados em `main.dart`: **compila**. | Nenhuma; a D7 só esconde os botões. |
| Permissões Android | Manifestos do `image_picker_android` e do ML Kit: **nenhum pede `CAMERA`** nem armazenamento; a galeria usa o seletor de fotografias do sistema. | O manifesto não muda. |
| A app pode ser terminada com a câmara aberta | README do `image_picker`: com pouca memória o Android termina a app; a fotografia recupera-se com `retrieveLostData()`. | **T5**: recuperar ao abrir Importar e exportar. |
| Faixas lentas na prova (9–18 s) | A prova gravava um PNG por faixa. `InputImage.fromBitmap` (RGBA em memória) existe e o Android trata-o (`InputImageConverter.handleBitmapImage`). | **T3**: faixas em memória, sem PNG; medir o tempo. |
| Rotação da fotografia (EXIF) | A fotografia de exemplo tem orientação 1 (normal): **não confirmado** que uma fotografia rodada se lê bem. | **T6**: fotografia ao alto e deitada. |
| E.Leclerc usa ponto decimal ("3.79") | `leclerc.dart`: valores `\d+\.\d{2}` e linhas que acabam num número, não numa letra. | **T1**: a regra "3.70 D" → vírgula só se aplica com a letra no fim; teste com as linhas do E.Leclerc intactas. |
| Escolhas de artigo na pré-visualização | Guardadas por `chaveEscolha(loja, texto)`. | **T4**: corrigir o texto de uma linha desliga a escolha anterior e o alias fica com o texto corrigido (escrito, com teste). |
| Repetidos dependem dos outros talões | `analisarTaloes` usa um conjunto `vistos` do lote todo. | **T4**: cada edição volta a analisar o lote todo (barato), não só o talão. |
| Nomes de ficheiro da galeria podem repetir-se | A chave do cartão é o nome do ficheiro. | **T5**: cada fotografia passa a "Fotografia N (nome)". |

### 0.5 Decisões (aprovadas)
| # | Decisão |
|---|---|
| D1 | OCR **no aparelho** (ML Kit, modelo latino embutido): a fotografia não sai do telemóvel, não é enviada nem guardada; o ficheiro temporário apaga-se depois de lido. |
| D2 | **Mesmo caminho dos PDFs**: foto → caixas → linhas → normalização → `lerTalao` → análise → pré-visualização → `importar_lote`. Os leitores continuam a receber texto. |
| D3 | **Imagem inteira primeiro; em faixas** (sobrepostas, ampliadas até ≈1440 px de largura) só se a inteira não for reconhecida ou não bater; fica o resultado que bate (ou, se nenhum bate, o com menos linhas por reconhecer). |
| D4 | **Mercadona — total:** o talão imprime o total em vários sítios (TOTAL, linha do pagamento, "COMPRA", soma da coluna "Valor c/IVA"); usa-se o que bater com a soma das linhas; se nenhum bater, o TOTAL e o talão fica "a rever". Data `AA-MM-DD`. Sem número de talão (repetidos pela loja + data + total, como já acontece sem número). |
| D5 | **Correção na pré-visualização** (pedido teu): editar texto, quantidade/peso e valor de uma linha, apagar e acrescentar linhas, corrigir total e data; o estado ("Novo"/"A rever") recalcula-se. Serve também para os PDFs. Nos talões de fotografia há "Ver fotografia" (com zoom) para comparar. |
| D6 | **Uma fotografia = um talão.** Talões compridos em várias fotografias ficam para `notas.md`. Na galeria podem escolher-se várias fotografias de uma vez (vários talões). |
| D7 | **Só Android**: na web e noutros sistemas os botões de fotografia não aparecem. |
| D8 | **Pingo Doce e E.Leclerc em papel** verificam-se na T6 com fotografias tuas; se o papel não for igual ao PDF, o leitor de papel faz-se nessa tarefa (com fixture fictícia). |

### 0.6 Regras
- Dados reais (fotografias, JSON do OCR, texto) só em `dados-privados/`; os testes do repositório usam fixtures fictícias.
- Lógica nova em Dart puro e testada no PC (reconstrução, normalização, leitor, edição); só a chamada ao ML Kit e o corte em faixas precisam do aparelho.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada, commit pequeno. Ficheiro partilhado: impacto pelo grafo antes de editar.

### 0.7 Fora do âmbito
iOS; OCR na web; talão em várias fotografias; recortar/endireitar a fotografia antes do OCR; ler o EAN; outras lojas; ler talões já importados de novo.

---

## T1 · Linhas a partir das caixas do OCR [x]
**Novo `lib/import/taloes/linhas_ocr.dart`** (Dart puro):
- `CaixaOcr(texto, esquerda, cima, direita, baixo, angulo)`.
- `linhasDasCaixas(List<CaixaOcr>) → String`: ângulo mediano → centro vertical corrigido; ordena; junta na mesma linha as caixas a menos de meia altura mediana; dentro da linha, ordena por x e junta com um espaço.
- `normalizarOcr(String) → String`: `(\d), (\d)` → `,`; `(\d) [xX] ?(\d)` e `^(\d+) X(\d)` → ` x `; `EUR/K[gG]` → `EUR/kg`; valor final `(\d+)\.(\d{2}) ([A-Z])$` → vírgula (só com a letra do IVA no fim: as linhas do E.Leclerc, `… 3.79 1`, ficam como estão); espaços repetidos → um.

**Testes (`test/taloes/linhas_ocr_test.dart`)**: caixas fictícias com descrição e preço separados → uma linha; talão inclinado (ângulo −2°) → linhas certas; duas linhas próximas não se juntam; cada regra da normalização, e que não toca em datas ("2024-09-22"), horas nem nas linhas do E.Leclerc (a fixture `leclerc.txt` passa por `normalizarOcr` e continua a ser lida igual).

## T2 · Leitor do Mercadona [x]
**Novo `lib/import/taloes/mercadona.dart`**; `lerTalao` passa a tentar também `lerMercadona`.
- Reconhece por "MERCADONA"; artigos entre a linha "Descrição…" e "TOTAL": `^(\d+) ?(.+?)(?: (\d+,\d{2}))? (\d+,\d{2}) [A-Z]$` (quantidade, texto, preço unitário opcional, valor, letra do IVA); sem preço unitário, unitário = valor ÷ quantidade.
- Total pela D4; data pela linha `^\d{2}-\d{2}-\d{2} \d{2}:\d{2}`. Linhas da zona dos artigos que não casam → `naoReconhecidas`.

**Testes**: fixture fictícia `test/fixtures/taloes/mercadona.txt` (como sairia do OCR): linhas com e sem preço unitário, TOTAL com um dígito perdido (o total vem da linha COMPRA e bate), linha estranha → "a rever"; `lerTalao` reconhece a loja; os leitores existentes não reconhecem o Mercadona e vice-versa.

## T3 · Texto da fotografia (aparelho) [x]
**Pacotes:** `google_mlkit_text_recognition: 0.17.1`, `image_picker: ^1.2.4` (`pubspec.yaml`, ficheiro partilhado).

**Novo `lib/import/taloes/texto_foto.dart`**:
- `typedef OcrDaFoto = Future<List<CaixaOcr>> Function(String caminho)` e `caixasDaFoto` (ML Kit, `TextRecognizer(script: latin)`, fechado no fim).
- `caixasEmFaixas(String caminho)`: `dart:ui` descodifica a imagem, corta as faixas, amplia-as e passa cada uma ao ML Kit em memória (`toByteData(rawRgba)` → `InputImage.fromBitmap`, sem ficheiros); devolve as caixas em coordenadas da imagem.
- A geometria fica em funções puras, testadas no PC: `faixasDa(largura, altura)` (altura ≈ 0,9 × largura, 120 px de sobreposição, escala até ≈1440 px de largura; como cada faixa só acaba depois da sobreposição, a última tem sempre mais de 120 px — o ML Kit recusa menos de 32; a faixa curta da prova vinha de um ciclo que continuava depois de cobrir a imagem) e `caixasDaFaixa(caixas, faixa)` (passa para coordenadas da imagem e só guarda as caixas com o centro fora da sobreposição).
- Medir o tempo por fotografia (inteira e em faixas) e registá-lo na T6.

**Novo `lib/import/taloes/ler_fotos.dart`** (como `ler_pdfs.dart`): para cada fotografia, D3 (inteira → `linhasDasCaixas` → `normalizarOcr` → `lerTalao`; se preciso, faixas) e devolve `(ficheiro, texto)` para `analisarTaloes`; as que falham ficam como não reconhecidas ("Fotografia ilegível" / "Formato de talão não reconhecido").

**Testes**: `faixasDa` (imagem baixa → uma faixa; alta → faixas sobrepostas que cobrem tudo; nenhuma faixa com menos de 32 px em muitos tamanhos; imagem estreita não fica em ciclo); `caixasDaFaixa` (deslocamento e escala certos; uma caixa na sobreposição só conta numa faixa); `ler_fotos` com um `OcrDaFoto` falso: inteira que bate não chama as faixas; inteira que não bate usa as faixas; nenhuma bate → fica a com menos estranhas; erro do OCR → não reconhecida. `test/taloes/fotos_reais_test.dart` (saltado sem `dados-privados/`): com o JSON da prova, Mercadona inteira e Lidl em faixas batem.

## T4 · Correção na pré-visualização [x]
**`importar_taloes.dart`**: `analisarTaloes` divide-se em ler (texto → `TalaoLido`) e `analisarTalao(ficheiro, TalaoLido, …)`, para voltar a analisar um talão editado sem reler o texto. `TalaoLido` ganha `copyWith`.

**`previsualizacao_taloes.dart`**:
- Menu ⋮ de cada linha ganha "Editar linha" (texto, quantidade ou peso, valor; dinheiro em cêntimos e peso em gramas pelos parsers que já existem) e "Apagar linha".
- No fim de cada talão: "Acrescentar linha"; as linhas por reconhecer aparecem em texto e, ao tocar, abrem "Acrescentar linha" preenchido.
- Cabeçalho do talão: "Corrigir total e data".
- Talões de fotografia: "Ver fotografia" (ecrã inteiro com `InteractiveViewer`).
- Cada edição volta a analisar o lote todo (o estado, os repetidos e o "já importado" dependem dos outros talões e do total/data).
- As escolhas de artigo são por texto (`chaveEscolha`): as das linhas cujo texto não mudou mantêm-se; corrigir o texto desliga a escolha anterior (volta a procurar o artigo pelo texto novo) e o alias guardado fica com o texto corrigido.
- Um talão que continue sem bater importa-se como hoje ("a rever", com a compra marcada para rever).

**Testes**: `analisarTalao` com linhas editadas passa de "A rever" a "Novo" quando bate; editar o texto volta a procurar o artigo; apagar e acrescentar linhas; widget: editar uma linha muda o valor e o estado no cartão; o lote (`loteDosTaloes`) leva os valores editados.

## T5 · "Talões (fotografia)" em Importar e exportar [x]
- Novo cartão/entrada "Talões (fotografia)" com "Tirar fotografia" (`ImagePicker.pickImage(source: camera)`) e "Escolher da galeria" (`pickMultiImage`); só quando `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` (D7).
- Progresso "A ler N fotografias…"; depois a mesma pré-visualização dos PDFs (título "Talões (fotografia)"), com "Ver fotografia".
- Ficheiros temporários apagados ao importar ou cancelar (D1). A fotografia não é reduzida (`pickImage` sem `maxWidth`/`imageQuality`): a letra do talão é pequena.
- Cada fotografia aparece como "Fotografia N (nome do ficheiro)", para não haver duas com a mesma chave.
- Se o Android terminar a app com a câmara aberta, ao abrir Importar e exportar `retrieveLostData()` recupera a fotografia e lê-a.

**Testes**: widget com `OcrDaFoto` e escolha de imagens falsos (injetados como o `LerTextoPdf`): os botões só aparecem no Android (`debugDefaultTargetPlatformOverride`) e nunca na web; uma fotografia lida aparece na pré-visualização; duas fotografias com o mesmo nome dão dois cartões; uma fotografia recuperada (`retrieveLostData`) é lida ao abrir; cancelar limpa.

## T6 · Verificação no telemóvel, docs e fecho [ ]
- No telemóvel: as 3 imagens de exemplo (galeria) e **fotografias novas tuas de talões em papel do Pingo Doce e do E.Leclerc** (D8); câmara e galeria; fotografia tirada com o telemóvel ao alto e deitado (rotação EXIF, 0.4); diálogos de edição com letra ×2 e com o telemóvel deitado; claro e escuro.
- Se Pingo Doce/E.Leclerc em papel não forem reconhecidos: leitor de papel nesta tarefa (fixture fictícia, mesmo padrão da T2) ou, se for grande, `notas.md` e decidimos.
- Tamanho do APK antes e depois.
- `mapa.md` (ficheiros novos), `ESTADO.md`, decisão `0012-ocr-no-aparelho.md` (D1–D3), plano marcado.

## Portão da Fase 7
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. No telemóvel: Mercadona e Lidl (exemplos) entram como "Novo"; Pingo Doce e E.Leclerc em papel verificados (D8); uma correção feita na pré-visualização chega à compra importada.
3. Na web os botões de fotografia não aparecem e os PDFs continuam a funcionar.
4. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Talões por fotografia: linhas a partir das caixas do OCR`
2. `Leitor de talões do Mercadona`
3. `OCR no aparelho com faixas para imagens altas`
4. `Pré-visualização de talões: corrigir linhas, total e data`
5. `Importar talões por fotografia (câmara e galeria)`
6. `docs: Fase 7`
