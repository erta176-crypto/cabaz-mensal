# Fase 6 · Tema azul (cabeçalho em gradiente, cartões brancos, verde/vermelho)

**Estado:** plano escrito a 2026-10-28, **à espera de aprovação**. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Origem: proposta do utilizador ("Painel e gaveta em azul", simulação HTML e prompt), revista contra o código. Substitui a paleta violeta da decisão 0008. A seguir: **Fase 7**, talões por fotografia (OCR; o que antes se chamava Fase 6).

---

## 0. Contexto e decisões

### O que existe hoje (confirmado no código)
- Todas as cores estão em `lib/core/tema.dart` (`Cores`, `_esquema`, `construirTema`); **não há `ThemeExtension`**. Os ecrãs usam o `colorScheme`. Teste de contraste em `test/tema_test.dart`.
- **Não há azul no código** (a "Lista azul" da proposta é da app antiga). A paleta atual é violeta (decisão 0008).
- Todos os ecrãs principais montam o cabeçalho na `Pagina` (`lib/features/shell/shell.dart`, `AppBar`). Os ecrãs que abrem por cima (Concluir compra, detalhe da compra) têm o seu próprio `AppBar`.
- Gaveta: `NavigationDrawer` em `AppShell` (cabeçalho com o cesto, o nome e o `BotaoTema`); barra inferior: `NavigationBar`.
- Cartão do orçamento: `lib/features/painel/orcamento_cartao.dart` (nível ok/quase/passou em `domain/orcamento.dart`; hoje cores `primary`/`tertiary`/`error`).

### Correções à proposta
| Na proposta | No projeto |
|---|---|
| "A Lista já usa azul" | Não usa; o azul passa a ser a cor principal de toda a app. |
| `TokensCabaz`, `.agent/rules/regras-agente.md`, `NOTAS.md` | Não existem: cria-se o `ThemeExtension` `CoresCabaz`; regras em `AGENTS.md`; notas em `docs/planning/notas.md`. |
| Rodapé da gaveta "Os dados ficam só neste dispositivo" | Falso (os dados sincronizam com o Supabase): **não entra**. |
| "Período: Outubro 2026" | As opções reais ficam ("Este mês", …). |
| Tokens `lojaLidl`, `lojaPingoDoce` | A cor de cada loja vem da base (`lojas.cor`); não são tokens. |
| Sem cor para "quase no limite" | Âmbar `#B06000` (já no HTML). |
| "Não alterar o tema escuro" | O escuro passa também a azul (decisão do utilizador). |

### Decisões (utilizador, 2026-10-28)
| # | Decisão |
|---|---|
| D1 | **Cabeçalho azul em gradiente em todos os ecrãs** (na `Pagina`), não só no Painel. Os ecrãs que abrem por cima ficam com o azul sólido. |
| D2 | **Tema escuro também azul**, com valores próprios e o mesmo teste de contraste. |
| D3 | Esta fase vem **antes** das fotografias (Fase 7). |
| D4 | **Os filtros ficam no corpo, como hoje** (não dentro do cabeçalho azul, ao contrário da simulação): assim são iguais em todos os ecrãs e continua a valer o `FiltrosEConteudo` (filtros que rolam com pouca altura). *Proposta — confirmar ao aprovar.* |

### Tokens
| Papel | Claro | Escuro |
|---|---|---|
| `primary` (azul; botões, ativos) / `onPrimary` | `#0B57D0` / `#FFFFFF` | `#A8C7FA` / `#062E6F` |
| gradiente do cabeçalho (início → fim) / texto | `#0B57D0` → `#1A6CE8` / `#FFFFFF` | `#0B3A8C` → `#1250B8` / `#FFFFFF` |
| indicador ativo (`secondaryContainer`) / texto sobre ele | `#D3E3FD` / `#0846AB` | `#1F3A6B` / `#D3E3FD` |
| fundo (`surface`) e cartões (`surfaceContainerLow`) | `#FFFFFF` / `#FFFFFF` | `#111418` / `#1A1F27` |
| contorno (`outlineVariant`) / pista das barras | `#DDE3EA` / `#E3E8EF` | `#2E3642` / `#2E3642` |
| texto / texto secundário | `#1A1C1E` / `#5F6368` | `#E4E7EC` / `#A9B1BD` |
| ok (dentro do limite, poupança) / fundo | `#1E7E34` / `#E6F4EA` | `#6DD58C` / `#0F3D1C` |
| quase (80–100 %) | `#B06000` | `#F6B26B` |
| alerta (ultrapassado) / fundo | `#C5221F` / `#FCE8E6` | `#F2B8B5` / `#5C1714` |

Contrastes já calculados no claro (≥ 4,5:1): branco/azul 6,4; branco/fim do gradiente 4,8; azul-escuro/azul-claro 6,5; texto secundário 6,1; verde 5,1; âmbar 4,65; vermelho/fundo 4,9. Os do escuro são verificados pelo teste da T1 (ajustar o tom e registar aqui se algum falhar).

### Regras
- Nenhuma cor solta nos ecrãs: tudo do `colorScheme` ou do `CoresCabaz`.
- A cor nunca é o único sinal (o texto "faltam/passou/quase no limite" fica).
- Antes de editar um ficheiro partilhado, dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com `dart format`, `flutter analyze`, `flutter test`, `graphify update .`, tarefa marcada, commit pequeno.
- Sem pacotes novos.

### Fora do âmbito
Mudar letras, tamanhos ou a ordem/conteúdo dos ecrãs; filtros dentro do cabeçalho (D4); cores das lojas.

---

## T1 · Paleta azul e `CoresCabaz` [ ]
- `lib/core/tema.dart`: `Cores` e `_esquema` com os valores da tabela (claro e escuro). `ThemeExtension<CoresCabaz>` com `gradienteInicio`, `gradienteFim`, `sobreGradiente`, `ok`, `okFundo`, `quase`, `alerta`, `alertaFundo`, `pista` (`copyWith`, `lerp`), registado nos dois `ThemeData`; `CoresCabaz.of(context)`.
- `appBarTheme`: fundo `gradienteInicio`, texto e ícones `sobreGradiente`, ícones da barra de estado claros (para os ecrãs que abrem por cima, sem gradiente).
- `cardTheme`: branco/`surfaceContainerLow`, contorno 1 px `outlineVariant`, raio 18, sem elevação.
- `docs/decisions/0011-paleta-azul.md` (substitui a 0008).
- **Testes** (`test/tema_test.dart`): contraste ≥ 4,5:1, claro e escuro, nos pares de texto do `colorScheme` e do `CoresCabaz` (`sobreGradiente` sobre os dois extremos do gradiente; `ok`, `quase` e `alerta` sobre o fundo e sobre os cartões; `alerta` sobre `alertaFundo`); valores do claro iguais à tabela; `CoresCabaz.of` existe nos dois temas.

## T2 · Cabeçalho azul em todos os ecrãs [ ]
- `Pagina`: `AppBar` com `flexibleSpace` em gradiente (`gradienteInicio` → `gradienteFim`, de cima/esquerda para baixo/direita), título e ações a branco, botão do menu com fundo branco a 16 % e raio 12, barra de estado clara.
- Sem mudar o conteúdo nem os filtros (D4).
- **Testes** (`test/shell_test.dart`): a `Pagina` tem o gradiente com as cores do tema, nos dois temas; o título fica com `sobreGradiente`.

## T3 · Gaveta e barra inferior [ ]
- Gaveta: cabeçalho com o mesmo gradiente; quadrado branco (raio 12) com o cesto em azul, "Cabaz Mensal" a branco e negrito, `BotaoTema` com fundo branco a 16 %. Itens com altura 52 e raio 26; ativo com fundo `secondaryContainer`, texto `onSecondaryContainer` e ícone `primary`; inativos com ícone `onSurfaceVariant`. `Divider` antes de "Importar e exportar". Ordem e destinos iguais.
- Barra inferior: fundo branco/superfície, contorno superior `outlineVariant`, indicador `secondaryContainer`, ícone e rótulo ativos em `primary`.
- Também no menu fixo do ecrã largo e com o telemóvel deitado (sem transbordos: os testes existentes têm de continuar verdes).
- **Testes**: o separador existe antes de "Importar e exportar"; o item ativo segue a rota; os testes de transbordo continuam verdes.

## T4 · Cartões de resumo e orçamento [ ]
- Painel, 4 cartões: rótulo em `onSurfaceVariant`, valor em negrito com algarismos tabulares (`FontFeature.tabularFigures`); "Poupança" em `ok`.
- Orçamento: barras com altura 6, raio 3, pista `pista`; cor por nível: `ok`, `quase`, `alerta`; percentagem gasta à direita do nome (mesma cor, ex.: "123 %"); legenda "passou X" em `alerta`; se o total passou, rótulo "Ultrapassado" (fundo `alertaFundo`, texto `alerta`) junto ao ⋮. O texto "faltam/passou/quase no limite" mantém-se.
- **Testes** (`test/painel_orcamento_test.dart`): percentagem certa (ex.: 420/500 → "84 %"); "Ultrapassado" só quando o total passou; a cor da barra segue o nível; a Poupança usa `ok`.

## T5 · Verificação visual, docs e fecho [ ]
- Ver no Android e no Chrome, claro e escuro, < e > 800 px, telemóvel deitado e letra do sistema a 200 %: todos os ecrãs, a gaveta e o orçamento.
- `mapa.md` (`CoresCabaz`), `ESTADO.md`, decisão 0011, marcar T1–T5.

## Portão da Fase 6
1. `dart format`, `flutter analyze`, `flutter test` verdes; `flutter build web` e `flutter build apk --release` compilam.
2. Contraste verificado pelo teste da T1 (claro e escuro).
3. Verificação visual da T5.
4. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Tema azul: paleta, CoresCabaz e decisão 0011`
2. `Cabeçalho azul em gradiente em todos os ecrãs`
3. `Gaveta e barra inferior no tema azul`
4. `Painel: cartões e orçamento com verde, âmbar e vermelho`
5. `docs: Fase 6`
