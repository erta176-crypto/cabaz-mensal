# 0010 · Texto dos talões em PDF com `pdfrx` (e `excel_community` no lugar do `excel`)

**Estado:** em vigor desde 2026-10-27 (Fase 5).

## Contexto
O `pdfrx` lê o texto dos PDFs com o PDFium (Android nativo, web por WASM). Todas as versões que compilam com o Dart do projeto precisam do `archive` 4; o `excel` 4.0.6 (última versão, de 2024) só funciona com o `archive` 3 e não compila com o 4 (`ZipDecoder.decodeBuffer`, `ArchiveFile.compress`). As versões do `pdfrx` compatíveis com o `archive` 3 (2.4.5) não compilam com o Dart atual.

## Opções consideradas
- **A — `pdfrx` 2.6.5 e trocar `excel` por `excel_community` 2.6.0** (fork comunitário do `excel`, mesma API, `archive` 4).
- **B — Manter o `excel` e ler PDFs com o pdf.js por interoperação JavaScript:** só na web; sem PDF no Android.

## Decisão
Opção A (escolhida pelo utilizador a 2026-10-27). Versões exatas, sem `^`: `pdfrx: 2.6.5`, `excel_community: 2.6.0` (as mais recentes com mais de 2 semanas).

## Consequências
- Entram `pdfrx`, `pdfrx_engine`, `pdfium_dart`, `pdfium_flutter`, `posix`, `rxdart`, `synchronized` (MIT, Apache-2.0); sobem `archive` 3.6.1 → 4.5.2, `image` 4.3.0 → 4.12.0, `pdf` 3.12.0 → 3.13.1, `xml` 6.6.1 → 7.0.1. `excel` sai.
- Só mudou o `import` em `lib/export/tabela_export.dart` e `lib/import/tabela_lida.dart`; os testes de ida e volta CSV/XLSX passam.
- APK release: 72,1 MB → 90,4 MB (PDFium para três arquiteturas; dá para reduzir com `--split-per-abi`). Web: `pdfium.wasm` (5,2 MB), descarregado só ao ler o primeiro PDF.
- `pdfrxFlutterInitialize()` chama-se na primeira leitura (`textoDoPdf`), não no arranque.
- Subir qualquer destes pacotes é uma decisão nova (o `excel_community` lança versões com frequência).
