# Visão geral

## Objetivo
Registar as compras de supermercado e perceber quanto se gasta e onde. Lojas habituais: Lidl, Pingo Doce e Mercadona.

- Um só código Flutter dá duas apps: Android (APK) e web, publicada em <https://erta176-crypto.github.io/cabaz-mensal/>.
- O telemóvel e o PC editam os mesmos dados, guardados no Supabase.
- A app funciona sem rede: as alterações ficam numa fila e sincronizam quando a ligação volta ([`sincronizacao.md`](sincronizacao.md)).
- Um único utilizador, em Portugal. Interface em português de Portugal; valores em euros no formato `1 234,56 €`.
- Histórico de partida: 139 compras, cerca de 690 artigos e 3 lojas.

## Base de dados (Supabase)
- **Tabelas:** lojas, categorias, artigos, aliases, compras, linhas_compra, registos_preco, itens_lista, preferencias.
- **Funções:**
  - `importar_seed`: importa o histórico em JSON;
  - `concluir_compra`: grava a compra feita a partir da lista;
  - `importar_lote`: grava uma importação de CSV ou XLSX numa só transação;
  - `agora`: devolve a hora do servidor, usada na sincronização.
- **Segurança:** todas as funções são `security invoker` e têm o `search_path` vazio. A RLS está ativa em todas as tabelas.

## Tecnologias
| Área | O que se usa |
|---|---|
| Linguagem da app | Dart 3.13 com Flutter 3.47 (Material 3) |
| Base de dados no servidor | SQL / PL/pgSQL (PostgreSQL do Supabase) |
| Base local | drift (SQLite; na web por `sqlite3.wasm`) |
| Estado e navegação | flutter_riverpod 3, go_router 18 |
| Servidor | supabase_flutter (auth + base de dados) |
| Ficheiros | file_picker, share_plus, excel, csv, pdf |
| Outros | connectivity_plus, intl, uuid, google_fonts, web |
| Publicação | GitHub Actions (`deploy-web.yml` → GitHub Pages, `build-apk.yml` → APK) |

## Ferramentas de desenvolvimento
- **Editor:** Antigravity com a extensão do Claude Code (principal); agente nativo do Antigravity às vezes; VS Code como secundário.
- **Regras dos agentes:** `AGENTS.md` (fonte única); `CLAUDE.md` importa-o.
- **Graphify:** grafo do código em `graphify-out/` (só local).
- **Claude Code:** plugins `flutter`, `dart-flutter` (com MCP) e `flutter-skills`; MCP Supabase; skills embutidas code-review, simplify, update-config.
- **Retirados para poupar tokens:**
  - Desinstalados: obsidian, impeccable, watch, ponytail.
  - Desativados: claude-code-setup, claude-security, image-generation. São sincronizados da conta claude.ai; reativam-se com `claude plugin enable <nome>@synced`.
  - Arquivados em `~/.claude/skills-arquivo/`: design-md, enhance-prompt, notebooklm, react-components, remotion, shadcn-ui, skill-creator, stitch-design, stitch-loop. Para repor uma, mover a pasta de volta para `~/.claude/skills/`.
