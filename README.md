# Cabaz Mensal

Registo de compras de supermercado (Lidl, Pingo Doce, Mercadona). Uma app Flutter com duas saídas a partir do mesmo código:

- **Android** (APK), para o telemóvel;
- **Web**, publicada em <https://erta176-crypto.github.io/cabaz-mensal/>.

As duas usam os mesmos dados, guardados no Supabase (Postgres na Europa, com acesso só para o dono de cada registo).

## Estrutura

```
lib/
  core/       tema, formatos pt-PT, router, configuração, guardar ficheiros
  domain/     modelos e regras (dinheiro em cêntimos, pesos em gramas)
  data/       repositórios abstratos + implementação Supabase (supabase/)
  import/     leitura do cabaz-seed.json, importação e exportação
  features/   um diretório por ecrã (shell, entrada, artigos, importar_exportar, definicoes, em_breve)
supabase/migrations/   esquema da base de dados (SQL versionado)
test/                  testes unitários e de widgets; test/integracao (opcional)
```

Só `lib/data/` fala com o Supabase. Os ecrãs usam os repositórios via Riverpod.

## Configurar o Supabase

1. Cria um projeto em <https://supabase.com/dashboard> (região na UE).
2. Aplica a migração: cola o conteúdo de `supabase/migrations/*.sql` no **SQL Editor** e carrega em **Run**. Com o Supabase CLI ligado ao projeto também podes usar `supabase db push`.
3. Em **Project Settings › API** copia o **Project URL** e a chave **anon / publishable**. Nunca uses a chave `service_role` na app.
4. Cria o ficheiro `env/local.json`, que é ignorado pelo git:

   ```json
   {
     "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
     "SUPABASE_ANON_KEY": "sb_publishable_..."
   }
   ```

5. Abre a app, cria a tua conta e depois desliga os registos novos em **Authentication › Sign In / Providers › Allow new users to sign up**. Assim mais ninguém se regista.

## Correr

```bash
flutter pub get

# PC (Chrome)
flutter run -d chrome --dart-define-from-file=env/local.json

# Telemóvel (com Depuração USB ligada)
flutter run --dart-define-from-file=env/local.json
```

## Importar o histórico

1. Põe o ficheiro em `dados-privados/cabaz-seed.json`. Esta pasta está no `.gitignore` e nunca vai para o GitHub nem para o APK ou o build web.
2. Na app, abre **Importar e exportar** no menu lateral e escolhe o ficheiro.
3. O resumo deve mostrar **138 compras, 693 artigos, 3 lojas e 4 652,26 €**, com ✓ em todas as lojas.

A importação é tudo-ou-nada: é feita numa única transação no servidor (função `importar_seed`). Se a conta já tiver dados, a app pergunta se os queres substituir. Nada é duplicado.

## Testes

```bash
flutter analyze
flutter test
```

`test/integracao/seed_real_test.dart` só corre se existirem `dados-privados/cabaz-seed.json` e `env/local.json` e se um Supabase **local** estiver a correr (`supabase start`, que precisa de Docker). Em qualquer outro caso, e no CI, faz skip. Nunca corre contra o projeto real.

## Gerar o APK

```bash
flutter build apk --release --dart-define-from-file=env/local.json
```

O ficheiro fica em `build/app/outputs/flutter-apk/app-release.apk`. Nesta fase é assinado com a chave de debug.

### Mais tarde: keystore própria (não a commites)

1. `keytool -genkey -v -keystore %USERPROFILE%\cabaz-mensal.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cabaz`
2. Cria `android/key.properties`, que não deve ser commitado: acrescenta-o ao `.gitignore`. Deve ter `storePassword`, `keyPassword`, `keyAlias` e `storeFile`.
3. Em `android/app/build.gradle.kts`, lê esse ficheiro e define um `signingConfig` de release (ver <https://docs.flutter.dev/deployment/android#sign-the-app>).
4. No CI, guarda a keystore em base64 e as palavras-passe como secrets do GitHub.

## Publicar

Em cada push para `main`, o GitHub Actions faz o seguinte:

- **Build APK** (`.github/workflows/build-apk.yml`): `flutter analyze`, `flutter test`, gera o APK e deixa-o como artefacto para descarregar.
- **Deploy web** (`.github/workflows/deploy-web.yml`): gera a versão web com `--base-href /cabaz-mensal/` e publica-a no GitHub Pages.

Antes do primeiro push:

1. Em **Settings › Secrets and variables › Actions**, cria `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
2. Em **Settings › Pages**, escolhe **Source: GitHub Actions**.

A web usa URLs com `#/` (estratégia por hash), para que atualizar a página (F5) não dê erro 404 no GitHub Pages.
