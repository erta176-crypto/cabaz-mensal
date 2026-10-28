# Fase 6 · Tema azul (cabeçalho em gradiente, cartões brancos, verde/âmbar/vermelho)

**Estado:** plano revisto e aprovado a 2026-10-28 (com a D4). Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Origem: proposta do utilizador ("Painel e gaveta em azul": simulação HTML, resumo e prompt), revista contra o código. Substitui a paleta violeta da decisão 0008. A seguir: **Fase 7**, talões por fotografia.

---

## 0. Contexto, provas e decisões

### 0.1 O que existe hoje (confirmado no código, 2026-10-28)
- **Cores:** todas em `lib/core/tema.dart` (`Cores`, `_esquema`, `construirTema`). Não há `ThemeExtension`. Teste de contraste em `test/tema_test.dart` (o único teste com cores fixas: os 4 valores violeta da paleta).
- **Cabeçalho:** todos os ecrãs principais usam a `Pagina` (`lib/features/shell/shell.dart`), que monta um `AppBar` com o fundo `surface`. Os ecrãs que abrem por cima (Concluir compra, detalhe da compra) têm o seu próprio `AppBar` e seguem o `appBarTheme`.
- **Gaveta:** `NavigationDrawer` no `AppShell`. O cabeçalho (cesto, "Cabaz Mensal", `BotaoTema`) é o primeiro filho. O `NavigationDrawer` deste Flutter (3.47.5) envolve tudo num `SafeArea(bottom: false)` e tem os parâmetros `header` e `footer`; o tema tem `tileHeight`, `indicatorColor`, `indicatorShape`, `labelTextStyle` e `iconTheme` (confirmado na fonte).
- **Barra inferior:** `NavigationBar` no `AppShell`. O `NavigationBarThemeData` **não tem contorno**.
- **Orçamento:** `lib/features/painel/orcamento_cartao.dart`, com `corDoNivel` (ok→`primary`, quase→`tertiary`, passou→`error`), barra `LinearProgressIndicator` de 8 px e texto "faltam/passou/quase no limite".
- **Cartões de resumo do Painel:** `_numeros` em `painel_page.dart` (rótulo `bodyMedium`, valor `headlineSmall`).

### 0.2 Onde cada papel de cor é usado (inventário)
| Papel | Onde | Com o azul fica |
|---|---|---|
| `primary` (17 usos + componentes) | botões cheios, interruptores da Lista, item selecionado do Histórico, barras "Por categoria", cesto da gaveta | azul |
| `primaryContainer` / `onPrimaryContainer` | indicador da barra inferior e da gaveta, botão flutuante ("Novo artigo"), realce ao arrastar ficheiros | azul-claro / azul-escuro |
| `secondary` | barras do gráfico "Gasto por mês" | azul mais vivo |
| `secondaryContainer` / `onSecondaryContainer` | faixa "Sem rede" e botões tonais ("Adicionar artigo") | azul muito claro / azul-escuro |
| `tertiary` | "quase no limite" do orçamento | âmbar |
| `tertiaryContainer` / `onTertiaryContainer` | aviso "Dados de …; sem rede" do Painel | âmbar claro / castanho |
| `error` / `errorContainer` (23 usos) | mensagens de erro, "passou" do orçamento, rodapé da Lista | vermelho / rosa |
| `surfaceContainerHighest` | cabeçalho dos meses no Histórico | cinzento-azulado |
| `inverseSurface` / `onInverseSurface` | dicas dos gráficos | cinzento-escuro / branco |

### 0.3 Mapa das cores (proposta, contraste calculado)
| Papel | Claro | Escuro |
|---|---|---|
| `primary` / `onPrimary` | `#0B57D0` / `#FFFFFF` | `#A8C7FA` / `#062E6F` |
| `primaryContainer` / `onPrimaryContainer` | `#D3E3FD` / `#0846AB` | `#1F3A6B` / `#D3E3FD` |
| `secondary` / `onSecondary` | `#1A6CE8` / `#FFFFFF` | `#8AB4F8` / `#0B2A5C` |
| `secondaryContainer` / `onSecondaryContainer` | `#E8F0FE` / `#0846AB` | `#243A5E` / `#D6E3F7` |
| `tertiary` / `onTertiary` (quase) | `#B06000` / `#FFFFFF` | `#F6B26B` / `#3D2400` |
| `tertiaryContainer` / `onTertiaryContainer` | `#FEEFC3` / `#6E3900` | `#4A3216` / `#FFDDB3` |
| `error` / `onError` (alerta) | `#C5221F` / `#FFFFFF` | `#F2B8B5` / `#601410` |
| `errorContainer` / `onErrorContainer` | `#FCE8E6` / `#8C1D18` | `#5C1714` / `#F9DEDC` |
| `surface` (fundo) / `onSurface` (texto) | `#FFFFFF` / `#1A1C1E` | `#111418` / `#E4E7EC` |
| `onSurfaceVariant` (texto secundário) | `#5F6368` | `#A9B1BD` |
| `surfaceContainerLowest` / `Low` (cartões) | `#FFFFFF` / `#FFFFFF` | `#0C0F13` / `#1A1F27` |
| `surfaceContainer` / `High` / `Highest` | `#F6F8FC` / `#EEF2F8` / `#E3E8EF` | `#1E242C` / `#252C36` / `#2E3642` |
| `outline` / `outlineVariant` (contornos) | `#8A94A3` / `#DDE3EA` | `#6F7A89` / `#2E3642` |
| `inverseSurface` / `onInverseSurface` | `#2E3135` / `#F1F3F6` | `#E4E7EC` / `#1A1C1E` |
| **`CoresCabaz`** (`ThemeExtension`) | | |
| `gradienteInicio` → `gradienteFim` / `sobreGradiente` | `#0B57D0` → `#1A6CE8` / `#FFFFFF` | `#0B3A8C` → `#1250B8` / `#FFFFFF` |
| `ok` (dentro do limite, poupança) | `#1E7E34` | `#6DD58C` |
| `pista` (parte vazia das barras) | `#E3E8EF` | `#2E3642` |

**Contraste calculado a 2026-10-28** (fórmula WCAG; 27 pares de texto por tema: cada `on…` sobre o seu fundo; `onSurface` e `onSurfaceVariant` sobre o fundo, os cartões e o `surfaceContainerHighest`; branco sobre os dois extremos do gradiente; `primary`, `tertiary`, `error` e `ok` sobre o fundo e os cartões; `error` sobre `errorContainer`; `ok` sobre o seu fundo):
- claro: mínimo **4,52** (texto secundário sobre o cabeçalho dos meses do Histórico), nenhum abaixo de 4,5:1. Branco sobre o gradiente: 6,4 e 4,8; âmbar 4,65; verde 5,1;
- escuro: mínimo **6,51**;
- barras (não texto, mínimo 3:1) sobre a pista: claro ok 4,17, quase 3,77, alerta 4,71; escuro ≥ 6,7.

`ok` fica no `CoresCabaz` (não há papel verde no `ColorScheme`); "quase" usa `tertiary`; "alerta" usa `error`/`errorContainer`.

### 0.4 Correções à proposta
| Na proposta | No projeto |
|---|---|
| "A Lista já usa azul" | Não usa (o azul era da app antiga); passa a cor principal de toda a app. |
| `TokensCabaz`, `.agent/rules/regras-agente.md`, `NOTAS.md` | Não existem: `ThemeExtension` novo `CoresCabaz` (só o que o `ColorScheme` não tem); regras em `AGENTS.md`; notas em `docs/planning/notas.md`. |
| Rodapé da gaveta "Os dados ficam só neste dispositivo" | Falso (sincronizam com o Supabase): **não entra**. |
| "Período: Outubro 2026" | Ficam as opções reais ("Este mês", …). |
| `lojaLidl`, `lojaPingoDoce` | A cor de cada loja vem da base (`lojas.cor`). |
| Sem cor para "quase" | `tertiary` âmbar `#B06000` (estava no HTML). |
| "Não alterar o tema escuro" | O escuro também fica azul (D2). |
| `okFundo` / `desceuFundo` | Não usado em nenhum ecrã: fica de fora. |

### 0.5 Decisões
| # | Decisão | Origem |
|---|---|---|
| D1 | Cabeçalho azul em gradiente em **todos** os ecrãs (na `Pagina`); os que abrem por cima ficam com o azul sólido (`appBarTheme`). | utilizador |
| D2 | Tema escuro também azul, com os valores da 0.3. | utilizador |
| D3 | Esta fase antes das fotografias (Fase 7). | utilizador |
| D4 | **Os filtros ficam no corpo, como hoje**, e não dentro do cabeçalho (diferença face à simulação): iguais em todos os ecrãs e continua a valer o `FiltrosEConteudo` (filtros que rolam com pouca altura). *Proposta — confirmar ao aprovar.* | revisão |
| D5 | Gradiente da gaveta até ao topo: tira-se a margem de cima ao `NavigationDrawer` (`MediaQuery.removePadding`) e põe-se essa altura **dentro** do cabeçalho em gradiente, que passa a ser o `header` do `NavigationDrawer` (fixo, não rola). | revisão (fonte do Flutter) |

### 0.6 Regras
- Nenhuma cor solta nos ecrãs: tudo do `colorScheme` ou do `CoresCabaz` (as cores das lojas continuam a vir da base).
- A cor nunca é o único sinal: o texto "faltam/passou/quase no limite" fica, e a percentagem acrescenta-se.
- Antes de editar um ficheiro partilhado, dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada, commit pequeno.
- Sem pacotes novos.

### 0.7 Fora do âmbito
Letras, tamanhos, ordem e conteúdo dos ecrãs; filtros dentro do cabeçalho (D4); cores das lojas; mudar o comportamento de qualquer ecrã.

---

## T1 · Paleta azul e `CoresCabaz` [x]
**`lib/core/tema.dart`**
- `Cores` com os valores da 0.3 (nomes por papel, ex.: `azul`, `azulClaro`, `azulEscuro`, `ambar`, `verde`, …) e `_esquema` com **todos** os papéis da tabela (claro e escuro).
- `class CoresCabaz extends ThemeExtension<CoresCabaz>` com `gradienteInicio`, `gradienteFim`, `sobreGradiente`, `ok`, `pista`; `copyWith`, `lerp` (`Color.lerp`), `static CoresCabaz of(BuildContext)` (lança se faltar, para não falhar em silêncio); `CoresCabaz.claro` e `CoresCabaz.escuro` constantes; registado em `extensions` nos dois `ThemeData`.
- `appBarTheme`: `backgroundColor: gradienteInicio`, `foregroundColor: sobreGradiente`, `titleTextStyle` com a cor `sobreGradiente`, `systemOverlayStyle: SystemUiOverlayStyle.light` (ícones da barra de estado claros sobre o azul).
- `cardTheme`: raio 18 (era 16), contorno 1 px `outlineVariant`, sem elevação (já era).
- `navigationDrawerTheme`: `tileHeight: 52`, `indicatorShape: StadiumBorder()`, `indicatorColor: primaryContainer`, `labelTextStyle` (ativo: `onPrimaryContainer`, w500; inativo: `onSurface`), `iconTheme` (ativo: `primary`; inativo: `onSurfaceVariant`).
- `navigationBarTheme`: fundo `surface`, `indicatorColor: primaryContainer`, `labelTextStyle` e `iconTheme` ativos em `primary`.
- `docs/decisions/0011-paleta-azul.md` (substitui a 0008, que passa a "substituída").

**Testes (`test/tema_test.dart`)**: substituir os 4 valores violeta pelos azuis; os pares de contraste da 0.3 nos dois temas (≥ 4,5:1 para texto, ≥ 3:1 para as barras sobre a `pista`); `CoresCabaz.of` funciona nos dois temas e `lerp` entre claro e escuro devolve as pontas em 0 e 1.

## T2 · Cabeçalho azul em gradiente em todos os ecrãs [x]
**`Pagina` (`lib/features/shell/shell.dart`)**
- `AppBar(backgroundColor: Colors.transparent, flexibleSpace: DecoratedBox(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [gradienteInicio, gradienteFim])))`; título e ações a `sobreGradiente` (vêm do `appBarTheme`).
- Botão do menu (☰): `IconButton.styleFrom(backgroundColor: sobreGradiente com 16 % de opacidade, shape: RoundedRectangleBorder(raio 12))`, área de toque ≥ 48 px.
- A faixa de sincronização continua por baixo do cabeçalho (não muda).
- Os ecrãs que abrem por cima ficam com o azul sólido do `appBarTheme`, sem código novo.

**Testes (`test/shell_test.dart`)**: a `Pagina` tem um `DecoratedBox` com o gradiente das cores do `CoresCabaz` (claro e escuro); o título é desenhado com `sobreGradiente`; o botão ☰ tem ≥ 48 px; os testes de transbordo existentes continuam verdes.

## T3 · Gaveta e barra inferior [ ]
**Gaveta (`AppShell`)**
- Cabeçalho passa a `NavigationDrawer.header`: `DecoratedBox` com o gradiente; `padding` em cima = margem de cima original (`MediaQuery.paddingOf(context).top`) + 8; o `NavigationDrawer` fica dentro de `MediaQuery.removePadding(removeTop: true)` (D5).
- Conteúdo do cabeçalho: quadrado 42×42 branco (`surface` do tema claro → no escuro `surfaceContainerLow`), raio 12, com o cesto em `primary`; "Cabaz Mensal" em `titleLarge` negrito, cor `sobreGradiente`; `BotaoTema` com o mesmo estilo do botão ☰ (fundo branco a 16 %, raio 12).
- `Divider(indent: 28, endIndent: 28)` entre "Artigos, categorias e lojas" e "Importar e exportar" (os `NavigationDrawer` contam só os `NavigationDrawerDestination`, por isso os índices não mudam).
- Itens: altura 52 e indicador em pílula (vêm do tema da T1). Ordem e destinos iguais.
- Também no menu fixo do ecrã largo (o mesmo widget) e com o telemóvel deitado (manter a correção da margem esquerda/direita da Fase 4).

**Barra inferior (`AppShell`)**: `NavigationBar` dentro de um `DecoratedBox` com contorno superior de 1 px `outlineVariant` (o tema não tem contorno).

**Testes (`test/shell_test.dart`)**: o separador está entre "Artigos…" e "Importar…" e os 6 destinos continuam a navegar; o item ativo segue a rota; o cabeçalho da gaveta tem o gradiente e começa no topo (com uma margem de cima de 24 px simulada, o gradiente cobre-a); a barra inferior tem o contorno; os testes de transbordo (telemóvel deitado, letra ×2, margens dos dois lados) continuam verdes.

## T4 · Cartões de resumo e orçamento [ ]
**Cartões do Painel (`_numeros`)**: rótulo em `onSurfaceVariant` (`bodyMedium`), valor em `headlineSmall` negrito com `FontFeature.tabularFigures()`; o valor da Poupança em `ok`.

**Orçamento (`orcamento_cartao.dart`)**
- `corDoNivel`: ok → `CoresCabaz.ok`, quase → `tertiary`, passou → `error`.
- Barra: `minHeight: 6`, raio 3, `backgroundColor: pista`.
- À direita do nome de cada linha, a percentagem gasta (`(gasto × 100 / orçamento).round()` + " %", na cor do nível; orçamento 0 → "—"), com algarismos tabulares. Nova função pura `percentagemGasta(LinhaOrcamento)` em `domain/orcamento.dart`.
- Legenda: igual (`textoOrcamento`); "passou" continua em `error`.
- Se o total do mês passou: rótulo "Ultrapassado" junto ao ⋮ (fundo `errorContainer`, texto `onErrorContainer`, raio total, `labelMedium`).

**Testes**: `percentagemGasta` (420/500 → 84; 491/400 → 123; orçamento 0 → null) em `test/orcamento_test.dart`; em `test/painel_orcamento_test.dart`: as percentagens aparecem ("84 %", "110 %"), "Ultrapassado" só quando o total passou, a barra de cada nível tem a cor certa, e a Poupança usa `ok`.

## T5 · Verificação visual, docs e fecho [ ]
- À mão, no Android e no Chrome, em claro e escuro: todos os ecrãs (Painel, Lista, Concluir compra, Histórico e detalhe, Artigos e Ver artigo, Importar e exportar com a pré-visualização dos talões, Definições, Entrada), a gaveta, a barra inferior e o orçamento; < e > 800 px, telemóvel deitado e letra do sistema a 200 %.
- `mapa.md` (`CoresCabaz`), `ESTADO.md`, decisão 0011 (e 0008 marcada como substituída), marcar T1–T5.

## Portão da Fase 6
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. Contraste verificado pelo teste da T1 (claro e escuro).
3. Verificação visual da T5 sem transbordos nem textos ilegíveis.
4. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Tema azul: paleta, CoresCabaz e decisão 0011`
2. `Cabeçalho azul em gradiente em todos os ecrãs`
3. `Gaveta e barra inferior no tema azul`
4. `Painel: cartões e orçamento com verde, âmbar e vermelho`
5. `docs: Fase 6`
