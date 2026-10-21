# 0004 · `docs/` fora do graphify

**Estado:** em vigor desde 2026-10-20.

## Opções consideradas
- **A — Excluir `docs/`:** o grafo fica só com código, extraído por AST (gratuito e exato). O estado e as decisões leem-se em `docs/ESTADO.md` e `docs/decisions/`.
- **B — Incluir `docs/`:** liga decisões e planos ao código, mas os `.md` passam por extração semântica com LLM (custo em tokens sempre que mudam) e geram ligações inferidas, que podem estar erradas.

## Decisão
Opção A. `docs/` está no `.graphifyignore`.

## Consequências
- O graphify responde "que código existe e como se liga"; `docs/` responde "em que fase estamos, o que falta e porquê".
- O `docs/ESTADO.md` tem de ser atualizado no fim de cada tarefa (regra em `AGENTS.md`) e verificado em cada portão.
