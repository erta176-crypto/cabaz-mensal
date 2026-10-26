# Fase 3 · Tema: paleta violeta/azul/castanho claro e modo escuro

**Estado:** plano aprovado a 2026-10-26. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

Executar tarefa a tarefa (T1 → T4). O que não está aqui não se faz: vai para `docs/planning/notas.md`.

---

## 0. Contexto e decisões (fechadas, não reabrir)

### O que existe hoje
- Todas as cores da app estão em `lib/core/tema.dart` (`Cores` e `_esquema`); os ecrãs usam `Theme.of(context).colorScheme`. Exceções que ficam como estão: a cor de cada loja (`lojas.cor`) e o verde de "comprado"/"novo" (`Colors.green.shade700`).
- `lib/app.dart` já passa `theme` e `darkTheme`; sem `themeMode`, a app segue sempre o tema do sistema. Não há escolha na app.
- O esquema atual não define `tertiary`/`tertiaryContainer`: o aviso de cache do Painel (que usa `tertiaryContainer`) sai num castanho escuro calculado pelo Flutter.
- `BaseLocal.lerEstado`/`gravarEstado` guardam pequenos valores locais; `limparTudo()` (outro utilizador / sair) apaga a tabela `estado` inteira.

### Decisões tomadas com o utilizador (2026-10-26)
| # | Decisão |
|---|---|
| D1 | **Paleta com violeta como cor principal**, azul como secundária (gráficos, informação), castanho claro/areia como terciária (avisos, realces suaves), fundo creme neutro. Valores na T1. Ver `docs/decisions/0008-paleta-violeta.md`. |
| D2 | **Tema: Sistema / Claro / Escuro** num menu nas Definições **e** um botão sol/lua no topo do menu lateral para trocar depressa. |
| D3 | **A escolha fica só neste aparelho** (tabela `estado`, chave `tema`). Sem migração, não sincroniza. Sobrevive a sair da conta. |

### Regras
- Só `lib/data/` fala com o drift. Os ecrãs usam providers.
- Contraste mínimo 4,5:1 para texto normal (teste automático na T1).
- Antes de editar um ficheiro partilhado (`lib/core/tema.dart` é usado por todos os ecrãs e testes; `lib/data/providers.dart`, `lib/data/local/base_local.dart`, `lib/domain/`), dizer o impacto segundo o graphify numa linha.
- Cada tarefa acaba com `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --reporter compact`, `graphify update .`, tarefa marcada aqui, commit pequeno.
- Sem pacotes novos.

### Fora do âmbito
Mudar letras, tamanhos ou formas dos componentes; menu lateral escuro no tema claro (estilo "Contas em Dia"); temas por loja; sincronizar o tema entre aparelhos.

---

## T1 · Paleta nova em `lib/core/tema.dart` [x]

> Feito a 2026-10-26: todos os pares passaram o contraste com os valores da tabela, sem ajustes.

Substituir os valores de `Cores` (e os nomes que deixam de fazer sentido, ex.: `terracota` → `violeta`) e completar `_esquema` com `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`, `secondaryContainer`/`onSecondaryContainer` em azul.

| Papel | Claro | Escuro |
|---|---|---|
| `surface` (fundo) | `#F8F6F2` creme | `#17151C` |
| `surfaceContainerLow` (cartões, menu) | `#FFFFFF` | `#211E28` |
| `surfaceContainer` / `High` / `Highest` | `#F3F0EC` / `#EEEAE5` / `#E8E3DD` | `#26222D` / `#2D2935` / `#35303E` |
| `onSurface` (texto) | `#26222E` | `#EDE9F3` |
| `onSurfaceVariant` (texto secundário) | `#625B6E` | `#B7AFC4` |
| `outline` / `outlineVariant` | `#ADA4B8` / `#E4DFE8` | `#6F6779` / `#38333F` |
| `primary` / `onPrimary` | `#5B4B9A` violeta / `#FFFFFF` | `#B8A9F0` / `#271C55` |
| `primaryContainer` / `onPrimaryContainer` | `#E9E4F7` lavanda / `#2E2463` | `#3D3270` / `#E6E0FA` |
| `secondary` / `onSecondary` | `#3A6EA5` azul / `#FFFFFF` | `#9EC3EA` / `#0E2F4F` |
| `secondaryContainer` / `onSecondaryContainer` | `#DCE8F5` / `#173A5E` | `#1F3F60` / `#D6E6F6` |
| `tertiary` / `onTertiary` | `#8A6A4F` castanho claro / `#FFFFFF` | `#D9BFA4` / `#3B2A1C` |
| `tertiaryContainer` / `onTertiaryContainer` | `#F1E6DA` areia / `#4A3424` | `#4A3A2C` / `#F3E4D4` |
| `error` / `onError` | `#B3261E` / `#FFFFFF` | `#F2B8B5` / `#601410` |

- Gráficos: `GraficoMeses` passa de `primary` para `secondary` (azul); "Por categoria" fica em `primary` (violeta). Os componentes que já usam `primaryContainer` (indicador do menu, botões tonais) ficam lavanda automaticamente.
- `docs/decisions/0008-paleta-violeta.md` (formato de `0005`), com D1.

**Testes (`test/tema_test.dart`)**: para claro e escuro, contraste ≥ 4,5:1 nos pares `onSurface/surface`, `onSurface/surfaceContainerLow`, `onSurfaceVariant/surface`, `onPrimary/primary`, `onPrimaryContainer/primaryContainer`, `onSecondary/secondary`, `onSecondaryContainer/secondaryContainer`, `onTertiaryContainer/tertiaryContainer`, `onError/error` (contraste = (L1 + 0,05) / (L2 + 0,05) com `Color.computeLuminance`). Se algum par falhar, ajustar o tom nesse papel (mais escuro no claro, mais claro no escuro) e registar o valor final aqui.

**Feito quando:** testes verdes (os testes de widgets existentes continuam verdes).

---

## T2 · Preferência do tema (dados) [x]

> Feito a 2026-10-26. O teste apanhou uma corrida: a leitura inicial podia apagar uma escolha feita logo no arranque; a escolha passa a prevalecer.

- `lib/domain/preferencias.dart`: `enum ModoTema { sistema('Sistema'), claro('Claro'), escuro('Escuro') }` com `rotulo`.
- `lib/data/local/base_local.dart` (impacto: `limparTudo` é chamado ao sair e ao mudar de utilizador): `limparTudo()` mantém a chave `tema` (é do aparelho, não da conta).
- `lib/data/providers.dart`: `temaProvider = NotifierProvider<TemaNotifier, ModoTema>`; `build()` começa em `ModoTema.sistema` e lê `baseLocalProvider.lerEstado('tema')` (valor = `ModoTema.name`; desconhecido → `sistema`); `escolher(ModoTema m)` atualiza o estado e grava `gravarEstado('tema', m.name)`.
- `lib/app.dart`: `themeMode` a partir de `ref.watch(temaProvider)` (`sistema` → `ThemeMode.system`, etc.).

**Testes (`test/tema_preferencia_test.dart`, `BaseLocal(NativeDatabase.memory())`)**: por omissão `sistema`; `escolher(escuro)` grava e um contentor novo lê `escuro`; valor inválido → `sistema`; `limparTudo()` mantém `tema` e apaga o resto; `limparCache()` mantém `tema`.

**Feito quando:** testes verdes.

---

## T3 · Controlos: Definições e botão sol/lua [x]

> Feito a 2026-10-26. `BotaoTema` e `MenuTema` em `lib/features/shell/tema_controlos.dart`; o botão entra no menu lateral pelo parâmetro `acaoMenu` do `AppShell` (como a `faixa`), para o `AppShell` não depender do Riverpod. A acessibilidade do botão vem do `tooltip` (lido pelo TalkBack como rótulo).

- **Definições** (`lib/features/definicoes/definicoes_page.dart`): novo `Card` "Aparência", antes de "Gestos na Lista", com `DropdownButtonFormField<ModoTema>` rotulado "Tema" (Sistema / Claro / Escuro).
- **Menu lateral** (`lib/features/shell/shell.dart`, cabeçalho "Cabaz Mensal"): `IconButton` à direita do nome. Ícone `Icons.dark_mode` quando o tema visível é claro, `Icons.light_mode` quando é escuro; `tooltip`: "Mudar para modo escuro" / "Mudar para modo claro". Tocar escolhe `escuro` ou `claro` (deixa de seguir o sistema). Área de toque ≥ 48 px. Aparece no menu fixo (≥ 800 px) e no ☰ (< 800 px).

**Testes (`test/tema_controlos_test.dart`)**: escolher "Escuro" nas Definições muda `Theme.of(context).brightness` para escuro; o botão no menu alterna claro ↔ escuro e o tooltip acompanha; o botão tem `Semantics` com o rótulo.

**Feito quando:** testes verdes.

---

## T4 · Verificação visual e documentação [ ]

- `docs/architecture/mapa.md`: `ModoTema`, `temaProvider`, chave `tema` na tabela `estado`.
- `docs/architecture/sincronizacao.md`: "A chave `tema` em `estado` é do aparelho: não sincroniza e `limparTudo` mantém-na."
- `docs/ESTADO.md` e marcar T1–T4.

## Portão da Fase 3
1. `dart format`, `flutter analyze`, `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. Contraste verificado pelo teste da T1.
3. Verificação visual de todos os ecrãs (Lista, Concluir compra, Painel, Histórico e detalhe, Artigos e Ver artigo, Importar e exportar, Definições, Entrada) em **claro e escuro**, < e > 800 px, na web e no Android.
4. A escolha do tema sobrevive a fechar e abrir a app, e a sair e entrar na conta.
5. `docs/` atualizado. O utilizador confirma o portão; só então o push.

## Commits
1. `Tema: paleta violeta, azul e castanho claro`
2. `Tema: preferência Sistema/Claro/Escuro guardada no aparelho`
3. `Tema: menu nas Definições e botão sol/lua no menu lateral`
4. `docs: Fase 3`
