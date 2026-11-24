# Fase 12 · Botão "+" para importar talões e Mercadona em PDF

**Estado:** aprovado (2026-11-24), com a T4 (Mercadona em PDF digital). Só Dart. Sem migração SQL e sem pacotes novos. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** chegar a uma importação de talões em 2 toques, a partir de qualquer ecrã com barra inferior.

## 0. O que existe (confirmado no código)
- `shell.dart`: abaixo de 800 px, a `NavigationBar` tem 4 destinos (Painel, Lista, Histórico, Artigos); "Importar e exportar" e "Definições" só estão no menu ☰, e nessas páginas a barra fica escondida. Acima de 800 px há só o menu lateral fixo.
- `importar_exportar_page.dart`: o tipo escolhido é `OQue` (`taloes` = PDF, `fotos` = fotografia); o estado começa em `OQue.artigos`. `_escolherFicheiro`, `_tirarFotografia` e `_escolherFotografias` abrem os seletores. A fotografia só existe no Android (`fotosNoAparelho`).
- Rota `/importar` sem parâmetros (`router.dart:85`).
- Artigos já tem um botão flutuante próprio (`FloatingActionButton.extended`, com texto).

## 1. Decisões
| # | Decisão |
|---|---|
| D1 | Opção A (aprovada a 2026-11-24): "+" redondo saliente no centro da barra inferior (2 destinos de cada lado). Abre uma folha inferior com atalhos. |
| D2 | Atalhos: "Talão em PDF", "Fotografar talão" e "Talão da galeria" (estes dois só no Android), "Outro ficheiro" (abre o Importar como hoje). |
| D3 | O atalho vai para `/importar?tipo=taloes|camera|galeria`. A página escolhe o `OQue` certo e, no Android, abre logo o seletor. Na web só escolhe o tipo: o navegador só abre o seletor de ficheiros a partir de um toque. |
| D4 | Acima de 800 px não há barra: o menu lateral ganha, no topo, a entrada "Importar talão", que abre a mesma folha. |
| D5 | O botão de Artigos fica como está: tem texto ("Novo …") e não se confunde com o "+". |

## T1 · Importar a partir de um tipo [x] (2026-11-24)
- Feito: `AtalhoImportar` e `escolherFicheirosProvider` (o `FilePicker` passa a poder ser substituído nos testes) em `importar_exportar_page.dart`; `router.dart` lê `?tipo=`. Testes em `importar_fotos_test.dart`.
- `router.dart`: passar o `tipo` do URL à `ImportarExportarPage`.
- `ImportarExportarPage({tipo})`: estado inicial e, no Android, abrir o seletor depois do primeiro frame.
- Testes de widget: com `tipo=taloes`, "O que importar" mostra "Talões (PDF)"; sem `tipo`, fica como hoje.

## T2 · "+" na barra e folha de atalhos [x] (2026-11-24)
- Feito: `_BotaoImportar` (gradiente do `CoresCabaz`, 56 px) no meio da `NavigationBar`; botão "Importar talão" no topo do menu lateral (também no ☰ do telemóvel). A `NavigationBar` dá a cada posição o papel de separador, que exige ação de toque: a semântica do "+" tem `onTap`. Testes em `shell_test.dart`.
- `shell.dart`: "+" central na barra (< 800 px) e entrada no menu lateral (≥ 800 px); folha com os atalhos de D2.
- Semântica ("Importar talão"), área de toque ≥ 48 px, cores do `CoresCabaz`.
- Testes de widget: o "+" existe abaixo de 800 px e não acima; tocar num atalho navega para `/importar?tipo=…`; os 4 destinos continuam a navegar.

## T4 · Mercadona "Fatura Simplificada" em PDF [x] (2026-11-24)
- Feito: `_dataPdf`, início dos artigos pela linha com "Descri", cabeçalho e rodapé de página ignorados, total com " €". Fixture fictícia `mercadona_pdf.txt`. Real: 67 linhas, bate; análise 104/104. O teste local `taloes_reais_test.dart` passa a ter o Mercadona no catálogo.
- Primeiro um teste com um talão fictício com a mesma estrutura (`Data de emissão: DD-MM-AAAA HH:MM`; `Qtd. Descrição P. Unit (€) Valor (€) Taxa`), que falha com "Talão sem data".
- `lerMercadona` passa a aceitar esta variante sem deixar de ler o talão em papel (testes atuais iguais).
- Talão real em `dados-privados/talões/Mercadona_/` passa a bater (total e linhas).

## T3 · Documentação [x] (2026-11-24)
- `mapa.md` (se aparecer ficheiro novo), `ESTADO.md`, este plano.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes.
- Verificação visual: claro e escuro, abaixo e acima de 800 px (`flutter run -d chrome`).
- No telemóvel (`adb install -r`): "+" → "Talão em PDF" abre o seletor de PDFs; "Fotografar talão" abre a câmara.

## Fora desta fase (talões novos em `dados-privados/talões/`, vistos a 2026-11-24)
- (O Mercadona em PDF digital passou para a T4.)
- Um PDF do Mercadona sem texto (imagem): só se lê com OCR.
- Intermarché por fotografia: não há leitor; é preciso o texto do OCR tirado no telemóvel.
