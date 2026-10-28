# 0012 · Talões por fotografia: OCR no aparelho

**Estado:** em vigor desde 2026-10-28 (Fase 7, D1–D3).

## Contexto
Os talões em papel (e as capturas de ecrã das apps das lojas) não têm texto como os PDFs. É preciso OCR, e os talões têm dados pessoais (NIF, cartão).

## Opções consideradas
- **A — OCR no aparelho** com o `google_mlkit_text_recognition` (modelo latino embutido): a fotografia não sai do telemóvel.
- **B — OCR num serviço externo** (por exemplo uma função no servidor): funcionaria na web, mas a fotografia sairia do aparelho.

## Decisão
Opção A (aprovada no plano da Fase 7):
- **D1:** OCR no aparelho, só no Android; a fotografia não é enviada nem guardada, e a cópia temporária apaga-se ao importar ou cancelar.
- **D2:** o mesmo caminho dos PDFs: caixas do OCR → linhas → normalização → `lerTalao` → análise → pré-visualização → `importar_lote`. Os leitores continuam a receber texto.
- **D3:** primeiro a imagem inteira; em faixas sobrepostas e ampliadas só se a inteira não for reconhecida ou não bater com o total.

## Consequências
- Entram `google_mlkit_text_recognition` 0.17.1 e `image_picker` ^1.2.4. A web compila, mas não mostra "Talões (fotografia)".
- APK release: 91,3 MB → 121,8 MB (modelo latino para três arquiteturas).
- **Release precisa de regras do R8** em `android/app/proguard-rules.pro`: `-dontwarn` para os modelos de outros alfabetos (sem eles a compilação falha) e `-keep` das classes do ML Kit (sem eles o `InputImage` falha com `NullPointerException` e todas as fotografias aparecem como ilegíveis). As compilações de debug não passam pelo R8: verificar sempre o OCR num APK release.
- O APK release compila-se com `--dart-define-from-file=env/local.json` (sem isso, a app abre sem a configuração do Supabase).
