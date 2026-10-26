# 0009 · Orçamento com id determinístico

**Estado:** em vigor desde 2026-10-26 (Fase 4).

## Opções consideradas
- **A — Id determinístico (uuid v5 de utilizador, mês e categoria):** a sincronização usa o caminho normal (chave = `id`, upsert por `id`).
- **B — Chave natural (`mes`, `categoria_id`) como em `itens_lista`:** o total tem `categoria_id` null, e o filtro do UPDATE e o `on_conflict` teriam de tratar o null (caso especial na sincronização).
- **C — Id aleatório:** dois aparelhos sem rede que criam o mesmo orçamento geram duas linhas; a segunda falha no índice único (erro permanente na fila).

## Decisão
Opção A. O índice único `orcamentos_unico (user_id, mes, categoria_id)` com `nulls not distinct` fica como segunda proteção.

## Consequências
- `idOrcamento` (`lib/domain/orcamento.dart`) usa um espaço de nomes fixo: **não pode mudar**, senão os ids novos deixam de bater com os gravados.
- Dois aparelhos que definem o mesmo orçamento sem rede: uma só linha, vence a última escrita a chegar.
- Apagar marca `apagado_em`; voltar a definir reativa a mesma linha.
