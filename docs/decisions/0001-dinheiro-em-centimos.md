# 0001 · Dinheiro em cêntimos e pesos em gramas

**Estado:** em vigor.

## Decisão
- Valores monetários guardados e calculados sempre em cêntimos inteiros.
- Pesos guardados em gramas.
- Implementação em `lib/domain/dinheiro.dart`.

## Consequências
- Nenhum cálculo de dinheiro usa `double`.
- Os valores só são formatados em euros (`1 234,56 €`) na interface e nas exportações.

*Motivo original não registado; acrescentar se for conhecido.*
