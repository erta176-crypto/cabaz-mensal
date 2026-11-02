# Fase 10 · Assinatura do release e ícone azul

**Estado:** plano aprovado a 2026-11-02. Sem migração SQL, sem pacotes novos e sem alterações em `lib/`. Depois de aprovado, as tarefas avançam sem pedir aprovação (decisão 0005).

**Objetivo:** o APK do CI instala-se por cima do local com `adb install -r`, sem desinstalar nada; o ícone deixa de ter a paleta antiga.

## 0. Contexto e decisões

### 0.1 O que existe (confirmado a 2026-11-02)
- `android/app/build.gradle.kts`: o release é assinado com `signingConfigs.getByName("debug")`. Localmente, isso é `~/.android/debug.keystore`; no CI, é uma chave gerada em cada máquina. Por isso os dois APKs têm assinaturas diferentes.
- A chave local: alias `androiddebugkey`, RSA 2048, válida até 2055. O SHA-256 do certificado é `E2:BF:AB:75:BF:8C:F3:99:B0:E2:5F:0D:F5:0D:E2:E9:28:15:14:BF:2B:6C:95:BC:83:46:94:63:B1:DE:8F:47`. O telemóvel aceitou-a no `adb install -r` de 2026-11-02.
- `android/.gitignore` já exclui `key.properties`, `**/*.keystore` e `**/*.jks`.
- `gh` não está instalado: os secrets do GitHub entram pela página do repositório.
- Ícone: `assets/icon/icone.png` (fundo `#FAF6F0` opaco) e `icone_primeiro_plano.png` (fundo transparente), ambos com o cesto em castanho e as ripas em `#FAF6F0`. Os ícones Android e da web são gerados a partir deles (`flutter_launcher_icons`, já no `pubspec.yaml`). Em `lib/` não há referências a `assets/icon`.

### 0.2 Decisões
| # | Decisão |
|---|---|
| D1 | Adotar a chave atual como chave de release: uma cópia própria fora do git, com palavra-passe nova, usada localmente e no CI. Não se desinstala a app. Se um dia houver Play Store, gera-se outra chave nessa altura. |
| D2 | Sem `key.properties`, o release **não** volta à chave de debug em silêncio: o build não produz um APK instalável. O CI confirma o SHA-256 do APK. |
| D3 | As palavras-passe e a chave nunca passam pela conversa nem pelos commits: é o utilizador que corre os comandos com palavra-passe e que preenche os secrets. |
| D4 | Ícone: cesto branco sobre fundo `#0B57D0`. As ripas ficam da cor do fundo (no primeiro plano, transparentes). |
| D5 | As imagens novas são recoloridas a partir das atuais, mantendo o desenho e o anti-aliasing. O script não fica no repositório. |

## T1 · Chave própria (utilizador) [ ]
Corridos pelo utilizador, com uma palavra-passe só para esta chave:
- Copiar `%USERPROFILE%\.android\debug.keystore` para `%USERPROFILE%\cabaz-mensal.jks`, sem mexer no original.
- `keytool -storepasswd` na cópia (e `-keypasswd`, se o formato da keystore o pedir; não confirmei qual é).
- Criar `android/key.properties` com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`.
- Guardar a chave e a palavra-passe num sítio seguro fora deste PC: sem elas, atualizar a app obriga a desinstalá-la.

## T2 · Gradle [ ]
- `build.gradle.kts`: ler `android/key.properties` e criar o `signingConfig` de release (D2).
- Confirmar os dois casos: com o ficheiro, o SHA-256 do APK é o de 0.1 (`apksigner verify --print-certs`); sem o ficheiro, não sai um APK instalável.

## T3 · CI [ ]
- Secrets, criados pelo utilizador **antes do push** (sem eles, o CI falha): `RELEASE_KEYSTORE_BASE64` e `RELEASE_KEYSTORE_PASSWORD`.
- `build-apk.yml`: descodificar a chave para fora do repositório, escrever `android/key.properties` e, depois do build, comparar o SHA-256 com o de 0.1 (com o `apksigner`, porque o `keytool -printcert -jarfile` não lê as assinaturas v2 e v3).
- O `deploy-web.yml` não muda.

## T4 · Ícone [x]
- Recolorir as duas imagens (D4, D5) e ver o resultado antes de gerar.
- `pubspec.yaml`: `adaptive_icon_background: "#0B57D0"`.
- `dart run flutter_launcher_icons`. Confirmar no diff que muda `colors.xml`, os `mipmap-*` e `web/icons/`, e que o `web/manifest.json` mantém as cores da Fase 9.
- Ver se o `web/favicon.png` é regenerado; se não for, atualizá-lo.
- Procurar `FAF6F0` e `B4532A` no repositório: em `android/`, `web/` e `pubspec.yaml` não pode sobrar nenhum.

## T5 · Documentação [ ]
- `docs/decisions/0014-chave-de-release.md`: a D1, com a alternativa recusada.
- `README.md`: substituir "Mais tarde: keystore própria" pelo que passa a existir.
- `notas.md`: retirar os dois pontos resolvidos.
- `mapa.md` se for preciso, `ESTADO.md` e este plano marcados.

## Portão
- `dart format --set-exit-if-changed lib test`, `flutter analyze` sem avisos e `flutter test --reporter compact`, todos verdes.
- No telemóvel, **só com `adb install -r`**, nunca desinstalar. Se a instalação for recusada, parar e rever; a app e os dados ficam como estão.
  - APK local por cima da app atual: instala, e a sessão e os dados continuam lá.
  - Depois do push, o APK do CI (artefacto `cabaz-mensal-apk`) por cima do local: instala, que é o objetivo da fase.
  - O ícone azul no ecrã inicial, em tema claro e escuro.
- Na web: o favicon e o ícone novos.
