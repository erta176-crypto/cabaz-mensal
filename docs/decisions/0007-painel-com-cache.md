# 0007 · Painel com cache do último resultado

**Estado:** em vigor desde 2026-10-25.

## Opções consideradas
- **A — Mostrar o último resultado guardado sem rede:** o resultado da RPC `painel` fica na tabela `estado` do drift; sem rede mostra-se com o aviso "Dados de <data e hora>; sem rede".
- **B — Painel só com rede:** sem rede, mensagem de erro. Mais simples, mas o painel fica inútil no telemóvel sem cobertura.
- **C — Guardar `compras` e `linhas_compra` na cache e calcular localmente:** muda a sincronização; fora do âmbito da Fase 2.

## Decisão
Opção A.

## Consequências
- O painel continua a calcular no servidor (RPC `painel`); a cache é só o último resultado por período e loja.
- `limparCache()` (reinício) e `limparTudo()` (sair da conta) apagam esta cache.
- O Histórico não usa cache: as compras não estão na cache local e, sem rede, mostra "Sem rede: o histórico precisa do servidor."
