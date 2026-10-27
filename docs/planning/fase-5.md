# Fase 5 · Talões em PDF

**Estado:** plano escrito a 2026-10-27, **à espera de aprovação**. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Executar tarefa a tarefa (T1 → T7). O que não está aqui não se faz: vai para `docs/planning/notas.md`. A seguir: Fase 6, talões por fotografia (OCR, só Android).

---

## 0. Contexto e decisões (fechadas, não reabrir)

### O que existe hoje
- **Importação da Fase 1B** (`lib/import/`): uma `TabelaLida` (colunas + linhas) com `Campo`s (`loja`, `data`, `local`, `artigo`, `textoTalao`, `quantidade`, `peso`, `precoUnit`, `bruto`, `desconto`, `pago`, `totalCompra`, …) passa por `analisarCompras` → `Previsualizacao` (linhas com estado Novo/Já existe/Erro, avisos, `LoteImportacao`) → cartão de pré-visualização → RPC `importar_lote`. O `Resolvedor` liga cada linha a um artigo pelo nome ou alias (`Catalogo`) e cria artigos novos quando não encontra. Deteta compras repetidas (`CompraExistente`).
- **`importar_lote` não grava aliases.** A tabela `aliases` é sincronizada (chave natural loja + texto + artigo) e escreve-se pela `Escrita`.
- **Talões reais de exemplo** em `dados-privados/talões/` (fora do git): Pingo Doce 24, Lidl 66, E.Leclerc 1 (PDF com texto); Mercadona 1 (fotografia, Fase 6). Têm dados pessoais: **nunca entram no repositório**; os testes usam talões fictícios escritos à mão com a mesma estrutura.
- **Convenção dos 145 talões já importados** (confirmada na base): `total_cent` = "TOTAL A PAGAR" (depois de todos os descontos, incluindo o "Saldo Pingo Doce"), `poupanca_cent` = soma dos descontos, e `total_cent` = soma do `pago_cent` das linhas (os descontos da compra inteira estão repartidos pelas linhas). Os talões novos seguem a mesma convenção.

### Formatos (estudados nos exemplos; ver T2)
| Loja | Linha de artigo | Quantidade / peso | Descontos | Total e data |
|---|---|---|---|---|
| Pingo Doce | `C NOME [q X preço] valor` (letra do IVA à frente; secções por categoria) | `0,996 X 7,99` na mesma linha | `Poupança Imediata (x)` na linha seguinte (do artigo anterior); `Descontos Extra` / `Saldo Pingo Doce (x)` (da compra) | `TOTAL A PAGAR`, `TOTAL POUPANÇA`; `Data de emissão:dd/mm/aaaa`; `Fatura Simplificada FS …` |
| Lidl | `NOME valor B` (letra do IVA no fim) | `2 x 1,99` ou `1,044 kg x 0,99 EUR/kg` na linha seguinte; às vezes `NOME 1,29 x 2 2,58 B` | `Promoção Lidl Plus -x`, `Promoção -x`, `DESCONTO 20% -x` (do artigo anterior) | `Total`; `Data de Venda: aaaa-mm-dd`; `No : FS …` |
| E.Leclerc | `23% NOME valor qtd` (IVA à frente, ponto decimal) | nome numa linha e `6% 2 X 5.89 11.78 2` na seguinte | (a confirmar com mais exemplos) | (a confirmar; 1 exemplo) |

### Decisões tomadas com o utilizador (2026-10-26/27)
| # | Decisão |
|---|---|
| D1 | **Pré-visualizar e confirmar** antes de gravar; avisar se o talão já foi importado. |
| D2 | **Em "Importar e exportar"**: nova opção "Talões (PDF)" em "O que importar"; vários PDFs de uma vez; arrastar e largar na web. |
| D3 | **Ligar na pré-visualização**: cada linha que criaria um artigo novo tem um menu para a ligar a um artigo existente (com pesquisa) ou criar um novo; ao gravar, o texto do talão fica como alias dessa loja (da próxima vez liga sozinho). |
| D4 | **`pdfrx`** (MIT, Android e web por WASM) para extrair o texto do PDF; é o único pacote novo. Ver `docs/decisions/0010-pdfrx.md`. |
| D5 | Descontos da compra inteira (ex.: "Saldo Pingo Doce") **repartidos pelas linhas** em proporção ao valor de cada uma (cêntimos que sobram vão para as linhas de maior valor), como nos talões já importados. |
| D6 | Compras importadas de talão ficam com `origem = 'talao'` e `ficheiro` = nome do PDF. |

### Regras
- Dinheiro em cêntimos inteiros; pesos em gramas. Leitura do texto em `lib/import/` (puro, testável); só `lib/data/` fala com o Supabase/drift.
- Antes de usar uma classe do `pdfrx`, confirmar a API na fonte do pacote (`~/.pub-cache`); não inventar.
- Antes de editar um ficheiro partilhado, dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada, commit pequeno.

### Fora do âmbito
Fotografias e OCR (Fase 6); outros supermercados além dos três; editar compras já gravadas; ler o EAN dos artigos a partir do talão; ler talões em HTML/e-mail.

---

## T1 · Pacote `pdfrx` e decisão 0010 [ ]
- `pubspec.yaml`: `pdfrx` na versão estável mais recente com mais de 2 semanas (confirmar no pub.dev; versão exata, sem `^`). `flutter pub get`; registar no plano a versão e as dependências novas que entram no `pubspec.lock`.
- Confirmar na fonte: abrir um documento a partir de bytes (`PdfDocument.openData` ou equivalente), `PdfPage.loadText()`, `pdfrxFlutterInitialize()` (onde e quando chamar), e o que é preciso para a web (WASM do PDFium; se precisa de ficheiros em `web/`).
- `lib/import/taloes/ler_pdf.dart`: `Future<String> textoDoPdf(Uint8List bytes)` (todas as páginas, separadas por `\n`), atrás de uma função injetável para os testes.
- `docs/decisions/0010-pdfrx.md`.
- Prova: `flutter build web` e `flutter build apk --release` compilam; num teste de integração manual (não automático, porque os PDFs são privados) ler um talão de `dados-privados/` na web e no Android e comparar o texto com o do `pdftotext`.

## T2 · Leitores de talões: `lib/import/taloes/` [ ]
Funções puras, testes primeiro, com **textos fictícios** em `test/fixtures/taloes/` (mesma estrutura, artigos e valores inventados, sem NIF, cartões nem moradas reais).

```dart
class TalaoLido {
  final String loja;            // nome da loja como no catálogo ('Pingo Doce', 'Lidl', 'E.Leclerc')
  final String? local;          // ex.: 'Entroncamento'
  final DateTime data;
  final String? numero;         // número da fatura ('FS …')
  final List<LinhaTalao> linhas;
  final int totalCent;          // o que se pagou (TOTAL A PAGAR / Total)
  final int descontoCompraCent; // descontos da compra inteira (ex.: Saldo Pingo Doce)
}
class LinhaTalao { final String texto; final int? quantidade; final int? pesoG;
  final int? precoUnitCent; final int brutoCent; final int descontoCent; }

/// Reconhece a loja pelo texto e lê o talão; null se o formato não é conhecido.
TalaoLido? lerTalao(String texto);
```
- Um leitor por loja (`pingo_doce.dart`, `lidl.dart`, `leclerc.dart`), escolhido por marcas do cabeçalho.
- Regras por loja como na tabela da secção 0; descontos com sinal (`(3,00)`, `-0,84`) somam ao `descontoCent` da linha anterior; secções e cabeçalhos ignorados; linhas que não se reconhecem ficam fora e geram um aviso.
- Verificação: soma de (`bruto − desconto`) − `descontoCompra` = `total`; se não bater, o talão é marcado para rever (aviso na pré-visualização) em vez de falhar.

Testes: um talão fictício por loja com todas as variantes (peso, quantidade inline e na linha seguinte, cada tipo de desconto, desconto da compra); texto de outra loja → null; linha estranha → aviso; soma que não bate → rever. Num teste local **não versionado** (fora de `test/`, só para correr à mão), confirmar que todos os talões de `dados-privados/talões/` leem sem erro e com a soma certa; registar aqui só as contagens (ex.: "24/24 Pingo Doce").

## T3 · Do talão à importação existente [ ]
- `lib/import/taloes/talao_para_tabela.dart`: `TabelaLida tabelaDeTaloes(List<(String ficheiro, TalaoLido talao)>)` com uma linha por linha do talão e as colunas `compra` (o número da fatura ou o ficheiro), `loja`, `local`, `data`, `artigo` (= texto do talão), `textoTalao`, `quantidade`, `peso`, `precoUnit`, `bruto`, `desconto` (já com a parte do desconto da compra, D5), `pago`, `totalCompra`.
- `analisarCompras` ganha `origem` (por omissão `'importacao'`, aqui `'talao'`) e `ficheiro` por compra (D6); compra repetida também quando o `ficheiro`/número já existe.
- Repartição do desconto da compra (D5) numa função pura com testes (soma exata, cêntimos para as maiores linhas, nenhuma linha negativa).

Testes: dois talões fictícios → 2 compras, linhas e totais certos, `poupanca` = descontos; talão já importado → "Já existe"; desconto da compra repartido.

## T4 · Ecrã: "Talões (PDF)" em Importar e exportar [ ]
- Em "O que importar", opção "Talões (PDF)"; o botão aceita vários `.pdf` (`file_picker`, já no projeto) e o arrastar e largar da web aceita PDFs.
- Lê cada PDF (`textoDoPdf` → `lerTalao`); os que não se reconhecem aparecem numa lista "Não reconhecidos" com o nome do ficheiro; os reconhecidos seguem para `tabelaDeTaloes` → `analisarCompras` → o cartão de pré-visualização que já existe → "Importar".
- Mensagens: "Formato de talão não reconhecido: <ficheiro>", "Talão já importado", aviso "A soma das linhas não bate com o total" (compra fica com `rever`).

Testes de widget com `textoDoPdf` falso: 2 PDFs (1 reconhecido, 1 não) → pré-visualização com 1 compra e a lista de não reconhecidos.

## T5 · Ligar linhas a artigos na pré-visualização (D3) [ ]
- No cartão de pré-visualização, para importações de talões, cada linha "Novo" (artigo a criar) tem um menu: "Criar «<texto>»" (por omissão) ou "Ligar a…" → diálogo com pesquisa sem acentos sobre os artigos (`normalizar`), como em Artigos.
- Ligar troca o artigo dessa linha (e de outras linhas iguais do mesmo lote) no `LoteImportacao` e retira o artigo novo do lote se mais nenhuma linha o usar.
- Depois de `importar_lote` dar certo, para cada ligação feita à mão grava-se o alias (`aliases`: loja, texto do talão, artigo) pela `Escrita` (sincroniza como os outros). Os artigos criados de novo também ficam com o alias do texto.

Testes: ligar uma linha muda o artigo no lote e remove o artigo novo; duas linhas iguais ligam juntas; depois de importar, os aliases ficam na fila; na importação seguinte do mesmo texto, a linha já aparece ligada.

## T6 · Verificação com os talões reais (local, sem versionar) [ ]
- Correr a importação na web e no Android com alguns talões reais de cada loja: os que já estão na base aparecem como "Já existe"; um talão novo importa e o Painel/Histórico mostram-no; os totais batem com o PDF.
- Registar aqui só contagens e resultados, sem valores reais.

## T7 · Documentação e fecho [ ]
`mapa.md` (`lib/import/taloes/`), `visao-geral.md` (pacote), decisão 0010, `ESTADO.md`, `notas.md` (o que ficar de fora), marcar T1–T7.

## Portão da Fase 5
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. Todos os talões PDF de `dados-privados/talões/` leem sem erro e com a soma certa (contagens registadas).
3. Importar talões já importados → todos "Já existe"; importar um talão novo → compra, linhas, preços e poupança certos (SQL de controlo).
4. Ligar uma linha a um artigo cria o alias; a importação seguinte desse texto liga sozinha.
5. Web e Android, claro e escuro, < e > 800 px.
6. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Pacote pdfrx e decisão 0010`
2. `Leitores de talões: Pingo Doce, Lidl e E.Leclerc`
3. `Talões para a importação existente, com desconto da compra repartido`
4. `Importar e exportar: talões em PDF`
5. `Pré-visualização: ligar linhas a artigos e guardar o alias`
6. `docs: verificação com talões reais`
7. `docs: Fase 5`
