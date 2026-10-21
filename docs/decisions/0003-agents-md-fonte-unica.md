# 0003 · `AGENTS.md` como fonte única das regras

**Estado:** em vigor desde 2026-10-20.

## Contexto
- O trabalho é feito no Antigravity, sobretudo com a extensão do Claude Code e às vezes com o agente nativo.
- O Claude Code carrega o `CLAUDE.md`; o agente nativo do Antigravity lê o `AGENTS.md`.
- As regras estavam duplicadas em `CLAUDE.md` e `regras-agente.md`.

## Decisão
- Todas as regras ficam no `AGENTS.md`.
- O `CLAUDE.md` contém `@AGENTS.md` e só o que é exclusivo do Claude Code.
- Não há `GEMINI.md` enquanto não houver regras exclusivas do Antigravity.
- O `regras-agente.md` é eliminado.

## Consequências
- Os dois agentes seguem as mesmas regras sem duplicação.
- O mapa do código saiu das regras (que são carregadas em todas as tarefas) para `docs/architecture/mapa.md`.
