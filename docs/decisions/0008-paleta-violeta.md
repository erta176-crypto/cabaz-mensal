# 0008 · Paleta violeta, azul e castanho claro

**Estado:** em vigor desde 2026-10-26 (Fase 3). Substitui a paleta terracota da Fase 0.

## Opções consideradas
- **A — Violeta principal:** botões e destaques em violeta, azul para gráficos e informação, castanho claro/areia nos avisos e realces suaves, fundo creme neutro.
- **B — Azul principal:** botões em azul, violeta só em realces.
- **C — Menu lateral escuro (estilo "Contas em Dia"):** menu ameixa escuro mesmo no tema claro.

## Decisão
Opção A. Valores em `docs/planning/fase-3.md` (T1) e `lib/core/tema.dart`.

## Consequências
- Todas as cores continuam só em `lib/core/tema.dart`; os ecrãs usam o `colorScheme`.
- O esquema passa a definir `tertiary`/`tertiaryContainer` (avisos em areia).
- O gráfico de gasto por mês usa `secondary` (azul).
- `test/tema_test.dart` garante contraste ≥ 4,5:1 nos pares de texto, em claro e escuro.
- Exceções que ficam: a cor de cada loja e o verde de "comprado".
