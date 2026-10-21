# Fase 1A · Lista e offline

**Estado:** concluída e publicada.

## Âmbito
- Lista do mês por loja.
- "Concluir compra": gera a compra, as linhas e os preços (função `concluir_compra`).
- Catálogo de artigos, categorias e lojas.
- Cache local drift com fila de sincronização (Android e web).
- Eliminação com `apagado_em`.
- Preferências.

## Migração
`supabase/migrations/`: `fase1a` (`apagado_em`, lista do mês, `preferencias`, `concluir_compra`).

Regras de sincronização: [`../architecture/sincronizacao.md`](../architecture/sincronizacao.md).
