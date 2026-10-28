# 0011 · Paleta azul (substitui a 0008)

**Estado:** em vigor desde 2026-10-28 (Fase 6).

## Opções consideradas
- **A — Azul e branco** (proposta do utilizador "Painel e gaveta em azul"): cabeçalho em gradiente azul, fundo e cartões brancos, verde/âmbar/vermelho para os níveis, em claro e escuro.
- **B — Manter a paleta violeta** (decisão 0008).

## Decisão
Opção A. Valores em `docs/planning/fase-6.md` (secção 0.3) e `lib/core/tema.dart`.

## Consequências
- Todas as cores continuam em `lib/core/tema.dart`: o `ColorScheme` (todos os papéis, claro e escuro) e o `ThemeExtension` `CoresCabaz` (gradiente do cabeçalho, verde de "dentro do limite", parte vazia das barras).
- "Quase no limite" usa `tertiary` (âmbar); "ultrapassado" usa `error`/`errorContainer`.
- `test/tema_test.dart` garante contraste ≥ 4,5:1 nos pares de texto e ≥ 3:1 nas barras, em claro e escuro.
- Os filtros do cabeçalho (pílulas e pesquisa) usam `fundoFiltro`/`textoFiltro`, claros nos dois temas, para contrastarem com o gradiente.
- As cores das lojas continuam a vir da base (`lojas.cor`).
