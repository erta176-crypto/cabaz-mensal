# 0014 · Chave de release: a chave de debug existente, copiada e protegida

**Estado:** em vigor desde 2026-11-15 (Fase 10, D1).

## Contexto
O release era assinado com a chave de debug. Localmente era a `~/.android/debug.keystore`; no CI, uma chave gerada em cada máquina. Os dois APKs tinham assinaturas diferentes, por isso o `adb install -r` do APK do CI não instalava por cima do local.

## Opções consideradas
- **A — adotar a chave de debug desta máquina:** copiá-la para um ficheiro próprio (`cabaz-mensal.jks`), com palavra-passe nova, fora do git, e usá-la local e no CI. O telemóvel continua a aceitar as atualizações e não se desinstala nada.
- **B — gerar uma chave nova:** é a solução convencional e fica pronta para a Play Store, mas obriga a desinstalar a app uma vez (perdem-se o tema e o bloqueio do aparelho e o que não foi sincronizado).

## Decisão
Opção A. O certificado continua a dizer "Android Debug"; se a app for para a Play Store, gera-se uma chave nova nessa altura.
- A chave e as palavras-passe nunca entram no repositório: `android/key.properties` e `*.jks` estão no `.gitignore`. No CI vêm dos secrets `RELEASE_KEYSTORE_BASE64` e `RELEASE_KEYSTORE_PASSWORD`.
- Sem `key.properties`, o release sai **sem assinatura** (nunca volta à chave de debug em silêncio). Localmente o build não avisa; o CI falha no passo que confere o SHA-256 do APK.
- Guardar o `.jks` e a palavra-passe fora do PC: sem eles, atualizar a app obriga a desinstalá-la.

## Atualizar os secrets do CI
Correr no PowerShell e colar no secret logo a seguir, sem copiar mais nada pelo meio (os comandos não mostram nada no ecrã):
- `RELEASE_KEYSTORE_BASE64` (texto que começa por `MII…`):
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\cabaz-mensal.jks")) | Set-Clipboard`
- `RELEASE_KEYSTORE_PASSWORD` (a do `key.properties`, igual para o keystore e para a chave):
  `((Get-Content "<projeto>\android\key.properties" | Select-String '^storePassword=').Line -replace '^storePassword=','').Trim() | Set-Clipboard`

O passo "Chave de release a partir dos secrets" mostra o tamanho do keystore descodificado (2618 bytes) e confere o SHA-256. Erros vistos a 2026-11-19: "3 bytes" = no secret ficou o comprimento do base64 em vez do base64; `keystore password was incorrect` no `packageRelease` = palavra-passe antiga no secret.
