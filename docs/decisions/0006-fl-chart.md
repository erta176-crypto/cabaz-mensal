# 0006 · Gráficos com `fl_chart` 1.2.0

**Estado:** em vigor desde 2026-10-25.

## Opções consideradas
- **A — `fl_chart` fixado em `1.2.0`:** MIT, Android e web, só depende de `equatable` e `vector_math` (já no `pubspec.lock`).
- **B — `fl_chart` 1.3.0:** saiu a 2026-10-21; demasiado recente.
- **C — Gráficos desenhados à mão com `CustomPainter`:** sem pacote, mas mais código e mais testes para barras, linhas e eixos.

## Decisão
Opção A, com versão exata (sem `^`).

## Consequências
- É o único pacote novo da Fase 2.
- Antes de usar uma classe do pacote, confirmar a API na fonte (`read_package_uris` / `rip_grep_packages`).
- Cada gráfico leva `Semantics(label: …)` com os valores em texto e o desenho dentro de `ExcludeSemantics`.
- Subir de versão é uma decisão nova, não uma atualização automática.
