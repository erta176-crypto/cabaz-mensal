# Fase 8 · Entrada: mostrar a palavra-passe e bloqueio com biometria

**Estado:** aprovado a 2026-10-30, com as decisões D1–D6. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** pedido do utilizador de 2026-10-27 (`notas.md`):
- no ecrã de entrada, um botão para ver a palavra-passe;
- no telemóvel, desbloquear a app com a impressão digital ou o rosto, e com o PIN como alternativa.

## 0. Contexto e decisões

### 0.1 O que existe (confirmado no código, 2026-10-30)
- `EntradaPage` (`lib/features/entrada/entrada_page.dart`): email e palavra-passe com `obscureText: true` fixo; botões "Entrar" e "Criar conta".
- Sessão: o `supabase_flutter` guarda a sessão no aparelho e renova-a sozinho. O router (`lib/core/router.dart`) manda para `/entrar` só quando não há sessão. Na prática, a sessão fica aberta até "Sair" (Definições).
- Preferências só deste aparelho: tabela local `estado` (ex.: `TemaNotifier`, chave `tema`).
- Android:
  - `MainActivity : FlutterActivity()`;
  - `LaunchTheme` e `NormalTheme` herdam de `@android:style/Theme.Light.NoTitleBar` e, no modo escuro, de `@android:style/Theme.Black.NoTitleBar`;
  - `minSdk = flutter.minSdkVersion`, que é 24.

### 0.2 Pacote (o plano nomeia-o)
| Pacote | Versão | Licença | Editor | Plataformas |
|---|---|---|---|---|
| `local_auth` | 3.0.2 | BSD-3 | flutter.dev | Android (SDK 24+), iOS, macOS, Windows; **sem web** |

Confirmado no pub.dev:
- A API é `authenticate({required localizedReason, biometricOnly = false, sensitiveTransaction = true, persistAcrossBackgrounding = false, authMessages})`. Devolve `false` se a pessoa falhar ou cancelar, e lança `LocalAuthException` nos outros casos.
- Para ver se o aparelho o suporta há `isDeviceSupported()` e `canCheckBiometrics`.
- Com `biometricOnly: false`, o diálogo do Android aceita também o PIN, o padrão ou a palavra-passe do ecrã.
- O Android exige três alterações:
  - `MainActivity : FlutterFragmentActivity()`;
  - a permissão `USE_BIOMETRIC`;
  - um tema `Theme.AppCompat` no `LaunchTheme`, para não falhar no Android 8 ou anterior.
- A versão 3.0.2 exige o Flutter 3.38 ou mais recente; o projeto usa o 3.47.5.

### 0.3 Decisões
| # | Decisão |
|---|---|
| D1 | O bloqueio é **local**: a sessão do Supabase não muda. A biometria e o PIN desbloqueiam a app; não substituem o email e a palavra-passe, nem os guardam. |
| D2 | O PIN é o **do telemóvel** (escolha do utilizador): `authenticate(biometricOnly: false)`. A app não guarda nenhum PIN. |
| D3 | Quando bloqueia (escolha do utilizador): **ao abrir a app** e **ao voltar a ela depois de 5 minutos ou mais** em segundo plano. |
| D4 | O bloqueio está **desligado por omissão**. Liga-se nas Definições, só no Android e só se `isDeviceSupported()` o permitir. Fica guardado neste aparelho (`estado`, chave `bloqueio`). Para ligar, é preciso um desbloqueio com êxito, para ninguém ficar trancado fora da app. |
| D5 | O ecrã de bloqueio tem dois botões: "Desbloquear", que pede o desbloqueio logo ao aparecer, e "Sair". O "Sair" termina a sessão e volta à entrada com email e palavra-passe, e é a saída para um bloqueio temporário ou para um telemóvel sem bloqueio de ecrã. Cancelar ou falhar mantém a app bloqueada. |
| D6 | Na web não há bloqueio; o "mostrar a palavra-passe" funciona em todo o lado. |

## T1 · Mostrar a palavra-passe [ ]
- No campo da palavra-passe, um `IconButton` com o ícone de olho alterna `obscureText`, com a dica "Mostrar palavra-passe" ou "Esconder palavra-passe".
- Teste de widget: o texto começa escondido e o toque mostra-o e volta a escondê-lo.

## T2 · Pacote e Android [ ]
- Juntar `local_auth: ^3.0.2` ao `pubspec.yaml`. Confirmar que resolve sem mudar outras versões.
- Alterações no Android:
  - `MainActivity` passa a herdar de `FlutterFragmentActivity`;
  - o manifesto ganha a permissão `USE_BIOMETRIC`;
  - `LaunchTheme` e `NormalTheme`, no claro e no escuro, passam a herdar de `Theme.AppCompat` (`Light.NoActionBar` e `NoActionBar`). A aparência deve ficar igual: o splash é verificado no telemóvel.
- `lib/core/desbloqueio.dart`: interface pequena `Desbloqueio` (`disponivel()`, `pedir()`), com a implementação do `local_auth` e um provider que se substitui nos testes, no mesmo padrão do `ocrFotosProvider`.
- Compilar o APK release e confirmar que o R8 não precisa de regras novas (lição da Fase 7: verificar em release).

## T3 · Definições: ligar o bloqueio [ ]
- Interruptor "Bloquear com impressão digital ou PIN": só aparece no Android e quando `disponivel()` é verdadeiro.
- Ligar exige um `pedir()` com êxito; desligar não pede nada.
- `BloqueioNotifier` guarda a escolha em `estado` (chave `bloqueio`), como o tema.
- Testes:
  - ligar com êxito grava a escolha;
  - um desbloqueio cancelado não liga o bloqueio;
  - na web o interruptor não aparece.

## T4 · Ecrã de bloqueio [ ]
- Por cima de todas as rotas (no `builder` do `MaterialApp.router`): se há sessão e o bloqueio está ligado, a app arranca bloqueada.
- Um `AppLifecycleListener` guarda a hora em que a app sai para segundo plano. Ao voltar, bloqueia se passaram 5 minutos ou mais (D3). A hora vem de um relógio injetável nos testes.
- No ecrã: o ícone e o nome da app, "Desbloquear", que pede logo ao aparecer, e "Sair" (D5). Para `LocalAuthException`, como o bloqueio temporário, mostra uma mensagem curta em português.
- Testes:
  - arranque bloqueado e desbloqueio;
  - um cancelamento mantém a app bloqueada;
  - volta antes e depois dos 5 minutos;
  - o "Sair" termina a sessão;
  - sem sessão ou com o bloqueio desligado, a app não bloqueia.

## T5 · Verificação no telemóvel, docs e fecho [ ]
- APK release instalado com `adb install -r`, para manter os dados.
- Verificar no telemóvel:
  - ligar o bloqueio;
  - fechar e abrir a app;
  - sair durante menos e durante mais de 5 minutos;
  - impressão digital, PIN e cancelar;
  - "Sair" no ecrã de bloqueio;
  - claro e escuro;
  - telemóvel deitado.
- Na web: "mostrar palavra-passe" funciona e não há interruptor de bloqueio.
- Registar o tamanho do APK antes e depois.
- Docs:
  - `mapa.md`;
  - `ESTADO.md`;
  - a decisão `0013-bloqueio-local.md` (D1–D3);
  - tirar o pedido de `notas.md`;
  - marcar o plano.

## Portão da Fase 8
1. `dart format`, `flutter analyze` e `flutter test` verdes, com a saída real; `flutter build web` e `flutter build apk --release` compilam.
2. No telemóvel, tudo o que a T5 lista funciona; os dados locais mantêm-se depois da instalação.
3. Na web, a entrada funciona como antes, com o botão de mostrar a palavra-passe.
4. `docs/` atualizado. O utilizador confirma o portão; só então o push. A Fase 7 continua por fechar, à espera do talão do Pingo Doce em papel.

## Fora do âmbito
- Esconder o conteúdo da app na lista de apps recentes (`FLAG_SECURE`).
- Um PIN próprio da app.
- O "Leaked Password Protection" do Supabase (pendente sem fase).
