# 0002 · Migrações aplicadas no SQL Editor

**Estado:** em vigor.

## Decisão
- As migrações ficam em `supabase/migrations/` e são aplicadas pelo utilizador no SQL Editor do Supabase.
- O `apply_migration` do MCP Supabase é recusado pelas permissões.

## Consequências
- O agente escreve a migração e pede ao utilizador para a aplicar.
- Depois de aplicada: verificar no servidor (SQL e logs) e correr os advisors.
