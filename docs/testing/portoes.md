# Verificação e portões

## Em cada tarefa
```
dart format --set-exit-if-changed .
flutter analyze
flutter test --reporter compact
```
Os três têm de passar, sem avisos no `analyze`. Mostrar a saída real.

## Testes automáticos
- Cerca de 100 testes.
- Servidor falso em memória e drift em memória (`test/sync/`). Nenhum teste usa o Supabase real.
- Cada lógica nova leva teste; nenhum teste é apagado, saltado ou enfraquecido para ficar verde.

## Portão de fase
1. Verificação acima verde, com a saída real.
2. Migrações da fase aplicadas pelo utilizador no SQL Editor e verificadas no servidor (SQL e logs). Advisors sem avisos novos.
3. Critérios do plano da fase cumpridos ([`../planning/`](../planning/)).
4. Verificação visual nos ecrãs alterados: claro e escuro, abaixo e acima de 800 px, web e Android (`adb install -r`).
5. `docs/` corresponde ao estado real: `ESTADO.md`, plano da fase, `mapa.md`, `sincronizacao.md`.
6. O utilizador confirma o portão; só então o push.
