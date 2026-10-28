# Fase 5 · Talões em PDF

**Estado:** plano revisto e aprovado a 2026-10-27 (com a D6). **T1–T8 feitas; portão confirmado pelo utilizador a 2026-10-28** (importação de talões em PDF a funcionar no Android e no Chrome). Publicado por partes a 2026-10-27 (T1–T5, depois T6) (importação de talões em PDF a funcionar, confirmada no Chrome); T6 (ligar linhas a artigos, nome/categoria, aliases), T7 e T8 por fazer; portão completo ainda não feito. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Executar tarefa a tarefa (T1 → T8). O que não está aqui não se faz: vai para `docs/planning/notas.md`. A seguir: Fase 6, talões por fotografia (OCR, só Android).

---

## 0. Contexto, provas e decisões

### 0.1 O que existe hoje (confirmado no código)
- **Importação da Fase 1B** (`lib/import/`, ecrã `lib/features/importar_exportar/importar_exportar_page.dart`):
  1. `lerFicheiro` → `TabelaLida` (cabeçalhos + linhas de texto);
  2. `adivinharColunas` → `List<Campo>` (`compra`, `data`, `loja`, `local`, `artigo`, `textoTalao`, `quantidade`, `peso`, `precoUnit`, `bruto`, `desconto`, `pago`, `totalCompra`, …);
  3. `analisarCompras(tabela, campos, Catalogo, List<CompraExistente>)` → `Previsualizacao` (uma `LinhaPrevia` por linha do ficheiro, com estado Novo/Já existe/Erro e aviso) + `LoteImportacao` (`artigos`, `compras`, `linhas`, `precos`);
  4. `PrevisualizacaoCard` mostra o resumo e as linhas; "Importar" → `DadosRepository.importarLote(lote.toJson())` (RPC `importar_lote`, uma transação) → `syncRepository.recarregarTudo()`.
- **Como `analisarCompras` decide:**
  - agrupa as linhas em compras pela coluna `compra` (ou loja+data+local+total);
  - compra **repetida** = mesma loja, mesmo dia e mesmo total que uma `CompraExistente` (vêm do servidor, `comprasExistentes()`; sem rede → aviso e sem deteção);
  - artigo de cada linha: `Resolvedor.artigoExistente(nome)` → `Catalogo.artigo` (igualdade do texto **normalizado** com o nome do artigo **ou** com um alias); se não houver, `criarArtigo(nome, unidade: kg se tem peso)` (reativa um apagado com o mesmo nome);
  - cada linha gera um `registos_preco` (`origem 'talao'`, preço unitário) e a compra fica com `rever = soma das linhas ≠ total` e `poupanca = soma dos descontos`.
- **`importar_lote`** grava sempre `compras.origem = 'importacao'` (não lê a origem do lote), aceita `ficheiro` e `rever`, e **não grava aliases**. A tabela `aliases` (loja, `texto_talao`, artigo) sincroniza pela `Escrita`.
- **Convenção dos 145 talões já importados** (confirmada na base):
  - `total_cent` = "TOTAL A PAGAR" (o que se pagou);
  - descontos da compra inteira (ex.: "Saldo Pingo Doce") **repartidos pelas linhas**, de forma que `total_cent` = soma de `pago_cent`;
  - `poupanca_cent` = soma dos descontos;
  - `texto_original` = texto do talão sem a letra do IVA e com acentos ("BRÓCOLOS KG");
  - nome do artigo criado = o mesmo texto com só a 1.ª letra maiúscula ("Brócolos kg");
  - `local` = "<Loja> <localidade>" ("Lidl Tomar", "Pingo Doce Entroncamento Lameira", "E.Leclerc Entroncamento");
  - peso em `peso_g`, quantidade inteira em `quantidade`;
  - `origem = 'importacao'`.
- **Talões reais** em `dados-privados/talões/` (fora do git; têm NIF e cartões): Pingo Doce 24, Lidl 66 (com cópias repetidas "… (1).pdf"), E.Leclerc 1 (PDF); Mercadona 1 (fotografia → Fase 6). **Nunca entram no repositório**; os testes usam talões fictícios.

### 0.2 Provas feitas antes de planear (2026-10-27, só no PC, fora do repositório)
- **Texto com o `pdfrx`:** com `pdfrx_engine` 0.8.0 (o motor do `pdfrx`), `PdfDocument.openData(bytes)` + `page.loadText()` → `PdfPageRawText.fullText` extraiu os **91 PDFs**. O texto sai limpo: uma linha por linha do talão e acentos certos. O `pdftotext -layout` partia colunas no Lidl e trocava acentos, por isso as regras são escritas sobre o texto do `pdfrx`.
- **Protótipo das regras da secção 0.3** sobre esse texto: **a soma das linhas − descontos bate certo com o total nos 91 talões** (Pingo Doce 24/24, Lidl 66/66, E.Leclerc 1/1; 1 338 linhas). O protótipo é descartável; as regras passam para Dart com testes.
- **Erros que o protótipo apanhou e que viram testes:**
  - o peso lê-se com as 3 casas ("0,332" → 332 g, não 330);
  - no Lidl há separadores `------------` no meio dos artigos (o fim é a linha `Total`);
  - no Lidl há uma forma de artigo em 3 linhas;
  - no Pingo Doce há secções com `+` ("MERCEARIA + PET FOOD").

### 0.3 Formatos (regras provadas; exemplos fictícios)
Comum: trabalhar linha a linha sobre `fullText` (linhas sem espaços nas pontas; linhas vazias ignoradas). Valores em cêntimos inteiros; pesos em gramas inteiros (3 casas decimais do kg).

**Pingo Doce** (reconhece-se por "Pingo Doce - Distribuição Alimentar")
- Local: 1.ª linha "PD <sítio>" → `local` "Pingo Doce <sítio>". Data: `Data de emissão:dd/mm/aaaa`. Número: `Fatura Simplificada FS <n>`.
- Artigos entre a linha `Artigos` e a linha `Resumo`:

  | Linha | Leitura |
  |---|---|
  | `C SALMAO POSTA KG 0,600 X 16,99 10,19` | letra do IVA + texto + `q X preço` + valor. Se o texto acaba em ` KG` ou `q` não é inteiro (`,000`) → peso (`q` kg → g); senão quantidade inteira |
  | `E FOLHADO DE SALSICHA 0,99` | letra + texto + valor (quantidade 1) |
  | `Poupança Imediata (3,00)`, `Exclusivo APP/Poupa Mais (0,05)`, `Exclusivo O Meu Pingo Doce (1,00)` — qualquer `<texto> (x)` antes de `Descontos Extra` | desconto do artigo anterior |
  | `Descontos Extra` e depois `<texto> (15,36)` | desconto da compra inteira (ex.: "Saldo Pingo Doce") |
  | linha só com maiúsculas, espaços e `/ . , & + -` (ex.: `PEIXARIA`, `MERCEARIA + PET FOOD`) | secção (guardar como sugestão de categoria, ver T6) |

- Total: `TOTAL A PAGAR <valor>` (o "TOTAL" sem "A PAGAR" é antes dos descontos).

**Lidl** (reconhece-se por "LIDL & Cia")
- Local: 1.ª linha "LIDL & Cia - <SÍTIO>" → "Lidl <Sítio>" (só a 1.ª letra de cada palavra em maiúscula). Data: `Data de Venda: aaaa-mm-dd`. Número: `No : FS <n>`.
- Artigos entre a linha `EUR` e a linha `Total <valor>`:

  | Linha(s) | Leitura |
  |---|---|
  | `MISTURA DE LEGUMES 3,98 B` | texto + valor + letra do IVA (quantidade 1) |
  | `PAO FORMA 14 CEREAIS 1,29 x 2 2,58 B` | texto + `preço x q` + valor |
  | `<artigo>` e na linha seguinte `2 x 1,99` | quantidade e preço do artigo anterior |
  | `<artigo>` e na linha seguinte `1,044 kg x 0,99 EUR/kg` | peso e preço/kg do artigo anterior |
  | `SALADA COM COENTROS` / `3 x 1,29` / `3,87 B` | forma em 3 linhas: texto, quantidade, valor |
  | `<qualquer texto> -0,84` (`Promoção`, `Promoção Lidl Plus`, `DESCONTO 20%`) | desconto do artigo anterior |
  | `------------` | ignorar (aparece também no meio) |

**E.Leclerc** (reconhece-se por "E.LECLERC" ou "TRONCADIS"; o cabeçalho vem com letras espaçadas: tirar os espaços para ler o sítio)
- Local: "E.Leclerc <Sítio>" (2.ª linha do cabeçalho). Data: linha `Caixa … aaaa-mm-dd hh:mm`. Número: o código da linha seguinte à data (não há "FS").
- Artigos entre a linha `IVA C/IVA Qde` e a linha `Total <n> artigos <valor>` (ponto decimal):

  | Linha(s) | Leitura |
  |---|---|
  | `23% NESCAFE C/ CAFEINA NESTLE 100G 3.79 1` | IVA + texto + valor + quantidade; `* ` antes do texto marca promoção (tirar) |
  | `AZEITE FRESCO O.SERRA 750ML` e `6% 2 X 5.89€ 11.78 2` | texto numa linha, quantidade e valores na seguinte |
  | `>> MERCEARIA` | secção |

- Os "ganhos" do cartão (saldo para a próxima compra) **não** são desconto desta compra. Só há 1 exemplo: outras variantes (descontos) tratam-se como linha não reconhecida → aviso e compra "a rever".

### 0.4 Decisões
| # | Decisão | Origem |
|---|---|---|
| D1 | Pré-visualizar e confirmar antes de gravar; avisar se o talão já foi importado. | utilizador |
| D2 | Em "Importar e exportar": opção "Talões (PDF)" em "O que importar"; vários PDFs de uma vez; arrastar e largar na web. | utilizador |
| D3 | Linhas sem artigo: ligar na pré-visualização a um artigo existente (com pesquisa) ou criar novo; ao gravar, o texto do talão fica como alias dessa loja. | utilizador |
| D4 | `pdfrx` 2.6.5 (MIT, Android e web por WASM) para o texto do PDF e, para o permitir, `excel_community` 2.6.0 no lugar do `excel` (decisão `0010-pdfrx.md`, opção A). | utilizador |
| D5 | Desconto da compra inteira repartido pelas linhas em proporção ao valor de cada uma; os cêntimos que sobram vão para as linhas de maior valor; nenhuma linha fica negativa. | convenção dos dados |
| D6 | **Proposta (confirmar ao aprovar):** `origem` fica `'importacao'`, como os 145 talões antigos, e `ficheiro` = nome do PDF. Marcar `'talao'` obrigaria a reescrever a RPC `importar_lote` numa migração, para uma distinção que os dados antigos não têm. | revisão do plano |
| D7 | Talões repetidos **no mesmo lote** (mesma loja e número, ex.: "… (1).pdf") contam uma vez; os outros aparecem como "Repetido neste lote". | revisão do plano |
| D8 | Artigo novo: nome = texto do talão com só a 1.ª letra maiúscula; unidade kg se a linha tem peso; categoria sugerida pela secção do talão quando há correspondência (T6), editável na pré-visualização. | convenção dos dados |

### 0.5 Regras
- Dinheiro em cêntimos inteiros, pesos em gramas. A leitura dos talões é pura e testável (`lib/import/taloes/`). Só `lib/data/` fala com o Supabase e o drift.
- Antes de usar uma classe do `pdfrx`, confirmar na fonte do pacote da versão escolhida.
- Antes de editar um ficheiro partilhado, dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada aqui, commit pequeno.
- **Privacidade:** nenhum texto de talão real em `test/`, `docs/` ou mensagens de commit; só contagens.

### 0.6 Fora do âmbito
Fotografias e OCR (Fase 6); outras lojas; editar compras já gravadas; marcar itens da Lista como comprados a partir do talão; ler o EAN; talões por e-mail/HTML; mudar a RPC `importar_lote`.

---

## T1 · Pacote `pdfrx`, leitura de texto e decisão 0010 [x]

> **Feito a 2026-10-27.** O `pdfrx` não resolvia com o `excel` 4.0.6 (`archive` 3 vs 4) e as versões antigas do `pdfrx` não compilam; por escolha do utilizador (opção A, decisão 0010): `pdfrx: 2.6.5` e `excel_community: 2.6.0` no lugar do `excel` (só mudaram 2 `import`). API confirmada na fonte: `pdfrxFlutterInitialize`, `PdfDocument.openData`, `pages`, `loadText()` → `fullText`, `dispose`; na web o `pdfium.wasm` vem nos assets do pacote. `textoDoPdf` testado com um PDF fictício gerado no teste (o PDFium corre no `flutter test`). 247 testes verdes; web e APK compilam (APK 72,1 → 90,4 MB). A leitura de talões reais no Chrome e no Android fica para a T5, com o ecrã.
- **Versão:** a mais recente estável do `pdfrx` com mais de 2 semanas (hoje 2.10.1 → confirmar a data no pub.dev; versão exata, sem `^`). `flutter pub get`; registar aqui a versão e os pacotes novos do `pubspec.lock`.
- **Confirmar na fonte da versão escolhida:**
  - `pdfrxFlutterInitialize()`: onde se chama (em `main.dart`, antes do `runApp`, ou só na primeira leitura);
  - `PdfDocument.openData(Uint8List)`, `document.pages`, `PdfPage.loadText()` → `PdfPageRawText?.fullText`, `document.dispose()`;
  - o que é preciso na **web** (o WASM do PDFium vem nos assets do pacote? é preciso alguma coisa em `web/`?);
  - quanto aumenta o APK e o `build/web`.
- **`lib/import/taloes/texto_pdf.dart`:**
  - `typedef LerTextoPdf = Future<String> Function(Uint8List bytes);`
  - `Future<String> textoDoPdf(Uint8List bytes)`: junta as páginas com `\n`; erros do PDF → `FormatException('PDF ilegível')`.
  - O ecrã recebe a função por provider, para os testes usarem uma falsa.
- `docs/decisions/0010-pdfrx.md` (formato de 0005) e `docs/architecture/visao-geral.md` (pacote).
- **Feito quando:**
  - `flutter build web` e `flutter build apk --release` compilam;
  - à mão, um talão real de cada loja lido na web (Chrome) e no Android dá o mesmo texto que o protótipo (comparar contagem de linhas).

## T2 · Modelo e leitor do Pingo Doce [x]

> **Feito a 2026-10-27.** Com os talões reais apareceram mais duas formas de desconto do artigo ("Exclusivo …"); a regra passou a geral (qualquer `<texto> (x)` antes de `Descontos Extra`). Em vez do script em `tool/`, a verificação com os talões reais é um teste (`test/taloes/taloes_reais_test.dart`) que lê `dados-privados/talões/` com o `pdfrx` e é saltado se a pasta não existir; só mostra contagens. **Pingo Doce: 24/24 batem.**
Testes primeiro (`test/taloes/pingo_doce_test.dart`), com textos **fictícios** em `test/fixtures/taloes/pingo_doce_*.txt` (estrutura igual, artigos/valores/sítios inventados, sem NIF nem cartões).

`lib/import/taloes/talao.dart`:
```dart
class LinhaTalao {
  const LinhaTalao({required this.texto, this.quantidade, this.pesoG,
    required this.precoUnitCent, required this.brutoCent, this.descontoCent = 0,
    this.seccao});
  final String texto;          // sem letra do IVA nem "* "
  final int? quantidade;       // null quando há peso
  final int? pesoG;
  final int precoUnitCent;     // por unidade ou por kg
  final int brutoCent;
  final int descontoCent;      // descontos do próprio artigo
  final String? seccao;        // ex.: 'PEIXARIA' (só Pingo Doce e E.Leclerc)
}
class TalaoLido {
  const TalaoLido({required this.loja, this.local, required this.data,
    this.numero, required this.linhas, required this.totalCent,
    this.descontoCompraCent = 0, this.naoReconhecidas = const []});
  final String loja;           // 'Pingo Doce' | 'Lidl' | 'E.Leclerc' (nome no catálogo)
  final String? local;
  final DateTime data;
  final String? numero;
  final List<LinhaTalao> linhas;
  final int totalCent;          // o que se pagou
  final int descontoCompraCent; // descontos da compra inteira
  final List<String> naoReconhecidas;
  /// soma(bruto − desconto) − descontoCompra == total
  bool get bate;
}
```
`lib/import/taloes/pingo_doce.dart`: `TalaoLido? lerPingoDoce(String texto)` com as regras da secção 0.3 (null se não é Pingo Doce).

Testes (um caso por regra):
- linha com peso (`… KG 0,332 X …` → 332 g) e com quantidade inteira (`2,000 X 0,87` → 2 un);
- linha sem `X`; `Poupança Imediata` no artigo anterior;
- `Descontos Extra` + `Saldo …` → `descontoCompraCent`;
- secções (incluindo uma com `+`) guardadas em `seccao` e não lidas como artigos;
- total do `TOTAL A PAGAR`, e não do `TOTAL`;
- local, data e número;
- uma linha estranha → `naoReconhecidas` e `bate` falso se a soma não fechar;
- texto de outra loja → null.

## T3 · Leitores do Lidl e do E.Leclerc e reconhecimento da loja [x]

> **Feito a 2026-10-27.** Talões reais: **Pingo Doce 24/24, Lidl 66/66, E.Leclerc 1/1 batem.** Limitação do E.Leclerc: o cabeçalho tem as letras espaçadas e perdem-se os espaços entre palavras, por isso só uma localidade de uma palavra fica certa (a real, "Entroncamento", fica).
- `lib/import/taloes/lidl.dart` (`lerLidl`) e `leclerc.dart` (`lerLeclerc`), com as regras da secção 0.3.
- `lib/import/taloes/ler_talao.dart`: `TalaoLido? lerTalao(String texto)` → tenta os três; null se nenhum reconhece.
- Testes com fixtures fictícias, uma por forma da tabela da secção 0.3:
  - Lidl: as 6 formas, incluindo o `------------` no meio e as três formas de desconto;
  - E.Leclerc: cabeçalho com letras espaçadas, linha em duas partes, `* `, `Total 35 artigos …`, os ganhos do cartão não contam como desconto;
  - `lerTalao` escolhe o leitor certo; texto sem loja → null.
- **Verificação com os talões reais:** acrescentar Lidl e E.Leclerc a `test/taloes/taloes_reais_test.dart` (saltado sem `dados-privados/`; só contagens). Meta: Lidl 66/66, E.Leclerc 1/1; registar aqui.

## T4 · Do talão ao lote de importação [x]

> **Feito a 2026-10-27.** Nomes finais: `EstadoTalao.novo/jaExiste/repetidoNoLote/aRever`, `NaoReconhecido(ficheiro, motivo)`, escolhas `LigarArtigo`/`NovoArtigo` por `chaveEscolha(lojaId, texto)`. A categoria sugerida fica para a T6. Com os talões reais: o pago das linhas soma o total em 91/91 depois de repartir o desconto da compra; as 3 cópias "(1)" saem como repetidas no lote.
`lib/import/taloes/importar_taloes.dart` (puro, testável), sem mexer em `analisarCompras`:
```dart
class TalaoAnalisado {
  final String ficheiro; final TalaoLido talao;
  final EstadoTalao estado;            // novo | jaExiste | repetidoNoLote | naoBate
  final String? compraId;              // no lote, quando novo/naoBate
  final List<LinhaAnalisada> linhas;
}
class LinhaAnalisada {
  final LinhaTalao linha; final int descontoTotalCent; // próprio + parte do desconto da compra (D5)
  final Artigo? artigo;                // existente (nome/alias) ou null
  final String nomeNovo;               // D8 (usado se artigo == null)
  final String? categoriaSugerida;     // id, T6
}
({List<TalaoAnalisado> taloes, List<String> naoReconhecidos}) analisarTaloes(
  List<({String ficheiro, String texto})> lidos, Catalogo cat, List<CompraExistente> existentes);
LoteImportacao loteDosTaloes(List<TalaoAnalisado> taloes, Map<String, EscolhaArtigo> escolhas, Catalogo cat, {String Function()? novoId});
```
- **Loja:** `cat.loja(talao.loja)`. Se a loja não existe no catálogo, o talão vai para os "não reconhecidos" com o motivo "Loja <x> não existe; cria-a em Artigos".
- **Repetidos:**
  - "Já existe": mesma loja, dia e total que uma compra do servidor (regra da importação atual, que apanha os 145 antigos);
  - "Repetido neste lote": mesma loja e número que um talão anterior do lote (D7).
- **Desconto da compra (D5):** `repartirDesconto(List<int> valores, int desconto) → List<int>` (pura). A soma é exata; os cêntimos que sobram vão para as linhas de maior valor; nenhuma linha fica com desconto maior do que o seu valor.
- **Artigo de cada linha:** `cat.artigo(texto)` (alias ou nome igual normalizado); senão `cat.artigo(nomeNovo)`; senão novo.
- **Lote**, para cada talão novo:
  - `compras` com `id`, `loja_id`, `local`, `data`, `total_cent` = `talao.totalCent`, `poupanca_cent` = soma dos descontos, `ficheiro`, e `rever` = `!talao.bate`;
  - `linhas` com `texto_original` = texto, quantidade/peso, preço unitário, bruto, desconto e pago;
  - `precos` com `origem 'talao'`;
  - `artigos` novos, criados pelo `Resolvedor` (que já reativa os apagados com o mesmo nome).
- `escolhas` (T6) substituem o artigo de uma linha: `ligar(artigoId)` ou `novo(nome, categoriaId)`.

Testes:
- 2 talões fictícios → 2 compras com totais, linhas, preços e poupança certos;
- um talão igual a uma compra existente → `jaExiste` e não entra no lote;
- duas cópias do mesmo talão → uma `repetidoNoLote`;
- `repartirDesconto`: exemplos com resto e proporção, e nenhuma linha fica negativa;
- uma linha com alias existente → liga sem criar artigo;
- uma linha sem correspondência → artigo novo "Filete de salmão" (D8), com kg se tem peso;
- duas linhas com o mesmo texto novo → um só artigo novo;
- `rever` quando a soma não bate;
- uma loja que não está no catálogo → não reconhecido, com o motivo.

## T5 · Ecrã: "Talões (PDF)" em Importar e exportar [x]

> **Código feito a 2026-10-27; falta a prova à mão (talões reais no Chrome e no Android).** Os testes ficaram em três peças em vez de um teste do ecrã inteiro (que exigiria simular o seletor de ficheiros, o servidor e uma dúzia de providers): `lerPdfs` (vários PDFs, ilegíveis à parte, progresso), `PrevisualizacaoTaloes` (resumo, estados, linhas, botões, sem rede) e a análise da T4. A `ZonaLargar` ganhou `aoLargarVarios` (vários PDFs na web). Um `.pdf` escolhido ou largado noutra opção muda para "Talões (PDF)". "Talões (PDF)" não aparece em Exportar.
>
> **Prova no Chrome (2026-10-27):** os PDFs leem-se e um talão já importado aparece "Já importado". Apanhou um erro anterior à Fase 5: o ecrã de importação montava o catálogo com `ref.read(aliasesProvider).value`, que vem vazio quando nenhum widget ouve o provider (no Riverpod 3 é até descartado enquanto carrega) — os aliases não eram usados (também na importação de CSV/Excel). Corrigido com teste: o ecrã ouve `providersDoCatalogo` no build e espera por eles (`carregarCatalogo`) antes de analisar.
- `OQue.taloes('Talões (PDF)', 'taloes')`: só para importar (não aparece em exportar); `paraImportar = [Formato.pdf]`; o botão usa `FilePicker.pickFiles(allowMultiple: true, allowedExtensions: ['pdf'])`; o arrastar e largar aceita vários `.pdf`.
- **Fluxo:**
  1. "A ler 3 de 12…";
  2. para cada PDF, `textoDoPdf`; um PDF ilegível vai para os não reconhecidos;
  3. `comprasExistentes()`; sem rede → mensagem "Sem rede: a importação de talões precisa do servidor." e pára (a gravação também precisa);
  4. `analisarTaloes`;
  5. `PrevisualizacaoTaloes` (novo widget, `lib/features/importar_exportar/previsualizacao_taloes.dart`).
- **`PrevisualizacaoTaloes`:**
  - resumo: "12 talões: 9 novos, 2 já importados, 1 repetido neste lote · 3 não reconhecidos";
  - um cartão por talão: loja · local · data · total, com o estado (Novo / Já importado / Repetido neste lote / A rever: "A soma das linhas não bate com o total"); os que não são novos ficam recolhidos;
  - nos talões novos, uma linha por artigo: texto do talão, quantidade ou peso, valor, e o artigo (nome do artigo existente, ou "Novo: <nome>" com o menu da T6);
  - a lista "Não reconhecidos": ficheiro e motivo;
  - botões "Cancelar" e "Importar N talões".
- "Importar":
  - `loteDosTaloes` → `importarLote` → gravar os aliases (T6) → `recarregarTudo()`;
  - mensagem "Importados 9 talões (214 linhas)";
  - em erro: "A importação falhou e nada foi alterado: …" (como hoje).

Testes de widget (`test/importar_taloes_page_test.dart`, com `textoDoPdf` falso e `DadosRepository` falso):
- 3 PDFs (1 Pingo Doce, 1 Lidl, 1 ilegível) → resumo e cartões certos;
- talão já existente aparece "Já importado" e não conta no botão;
- "Importar" envia o lote com 2 compras;
- sem rede → mensagem.

## T6 · Ligar linhas a artigos e categoria dos artigos novos (D3, D8) [x]

> **Feito a 2026-10-27.** Menu ⋮ nas linhas com artigo novo ("Ligar a um artigo…" com pesquisa sem acentos por nome ou EAN, "Mudar o nome…", "Categoria…", "Desfazer"); a escolha vale para o mesmo texto na mesma loja. Categoria sugerida pela secção (`seccoes.dart`). `loteDosTaloes` devolve também os aliases (textos sem correspondência ou ligados à mão), gravados por `ArtigosRepository.guardarAlias` **depois** de importar e recarregar (sincronizam pela fila).
- Em cada linha "Novo: <nome>", menu ⋮:
  - "Ligar a um artigo…": diálogo com pesquisa sem acentos (`normalizar`, a mesma regra de Artigos: nome ou EAN) sobre os artigos ativos;
  - "Mudar o nome…": campo de texto, por omissão o nome D8;
  - "Categoria": `DropdownButtonFormField` com as categorias, por omissão a sugerida.
- Escolher numa linha aplica a todas as linhas do lote com o mesmo texto e a mesma loja.
- **Categoria sugerida:**
  - `lib/import/taloes/seccoes.dart` tem um mapa fixo de secção → nome de categoria usado na app (ex.: `PEIXARIA` → "Peixe", `FRUTAS E VEGETAIS` → "Frutas e legumes"), escrito a partir das secções dos talões reais e das categorias da base;
  - só sugere se a categoria existir no catálogo, e se não houver sugestão fica "Sem categoria".
- **Aliases:** depois de `importarLote` dar certo, `ArtigosRepository.guardarAlias(lojaId, textoTalao, artigoId)` (novo, pela `Escrita.inserir('aliases', …)`) para:
  - cada texto ligado à mão;
  - cada artigo novo cujo nome normalizado seja diferente do texto (por ter sido renomeado).

  Isto garante que da próxima vez o texto liga sozinho.

Testes:
- ligar uma linha troca o artigo no lote e retira o artigo novo se ninguém mais o usa;
- duas linhas iguais ligam juntas;
- mudar o nome e a categoria de um novo vai para o lote;
- sugestão de categoria por secção;
- depois de importar, os aliases estão na fila (`Dispositivo` dos testes de sincronização);
- numa segunda análise, o mesmo texto já aparece ligado.

## T7 · Verificação com os talões reais (local) [x]

> **Feita a 2026-10-28:** o utilizador importou no Android um talão novo do Lidl. No servidor: 10 linhas, total = soma do pago, poupança = soma dos descontos, linhas coerentes, 10 preços com origem `talao`, sem "a rever", com local; 2 artigos novos com a categoria sugerida pela secção; 3 aliases novos. Antes disso: Já verificado: os 91 talões reais leem certo (teste local), talões já importados aparecem "Já importado" no Chrome e os aliases ligam os artigos existentes.
Na web e no Android, com talões de `dados-privados/talões/`:
- importar todos os Pingo Doce, Lidl e E.Leclerc → todos "Já importado" (já estão na base) e as cópias "(1)" "Repetido neste lote";
- apagar à mão no SQL Editor **uma** compra de teste (ou usar um talão novo da semana) → importá-la de novo → compra, linhas, preços e poupança batem com o SQL de controlo e com o PDF;
- ligar uma linha a um artigo → o alias aparece em `aliases`; reimportar (depois de apagar) → liga sozinho.

Registar aqui só contagens e resultados, sem valores reais.

## T8 · Documentação e fecho [x]

> **Feito a 2026-10-27.** Docs atualizados ao longo das tarefas (`mapa.md`, `visao-geral.md`, decisão 0010, `notas.md`); o portão completo espera pela T7.
- `mapa.md` (`lib/import/taloes/`, `PrevisualizacaoTaloes`), `visao-geral.md` (pacote), decisão 0010, `ESTADO.md`, marcar T1–T8.
- `notas.md`: mais variantes do E.Leclerc; Mercadona (Fase 6); se valer a pena, `origem 'talao'` (mudança na RPC).

## Portão da Fase 5
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam (tamanhos registados).
2. Verificação local: os 91 PDFs leem com `bate` (contagens registadas).
3. Importar talões já na base → todos "Já importado"; um talão novo → compra, linhas, preços e poupança certos (SQL de controlo).
4. Ligar uma linha cria o alias; a importação seguinte desse texto liga sozinha.
5. Web e Android, claro e escuro, < e > 800 px e telemóvel deitado.
6. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Pacote pdfrx: texto dos PDFs e decisão 0010`
2. `Talões: leitor do Pingo Doce`
3. `Talões: leitores do Lidl e do E.Leclerc`
4. `Talões: análise e lote de importação`
5. `Importar e exportar: talões em PDF`
6. `Talões: ligar linhas a artigos, categoria sugerida e aliases`
7. `docs: verificação com talões reais`
8. `docs: Fase 5`
