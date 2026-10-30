# 0013 · Bloqueio local com biometria ou o PIN do telemóvel

**Estado:** em vigor desde 2026-10-30 (Fase 8, D1–D3).

## Contexto
O utilizador pediu para entrar com o PIN e com a biometria. O `supabase_flutter` já guarda a sessão no aparelho e renova-a sozinho, por isso a sessão fica aberta até "Sair". O que falta é proteger a app aberta, não outra forma de entrar no Supabase.

## Opções consideradas
- **PIN:**
  - **A — o PIN do telemóvel**, com o `local_auth` e `biometricOnly: false`: a app não guarda nenhum PIN.
  - **B — um PIN próprio da app:** funcionaria também na web, mas é preciso criar, mudar e esquecer o PIN, limitar as tentativas e guardá-lo com hash. Um PIN de 4 algarismos adivinha-se depressa se alguém copiar os dados do aparelho.
- **Quando bloquear:** só ao abrir a app, sempre que se volta a ela, ou ao abrir e ao voltar depois de 5 minutos.

## Decisão
- **D1:** o bloqueio é local. A sessão do Supabase não muda, e a app não guarda a palavra-passe.
- **D2:** opção A, o PIN do telemóvel.
- **D3:** a app bloqueia ao abrir e ao voltar a ela depois de 5 minutos ou mais em segundo plano. Uma troca rápida de app, como tirar uma fotografia, não bloqueia.

## Consequências
- Entra o `local_auth` 3.0.2 (flutter.dev, BSD-3; sem web).
- O Android passa a ter:
  - `MainActivity : FlutterFragmentActivity`;
  - a permissão `USE_BIOMETRIC`;
  - temas de arranque `Theme.AppCompat`.
- O R8 não precisou de regras novas.
- O APK release passou de 121,8 MB para 122,4 MB.
- No `local_auth` 3, cancelar lança `LocalAuthException(userCanceled)` em vez de devolver `false`. A `semDesbloqueio` trata os cancelamentos como `false` e os outros erros como mensagens em português.
- O bloqueio está desligado por omissão e fica guardado só neste aparelho (`estado`, chave `bloqueio`). Para o ligar, é preciso um desbloqueio com êxito. Sair da conta desliga-o.
- Na web não há bloqueio.
