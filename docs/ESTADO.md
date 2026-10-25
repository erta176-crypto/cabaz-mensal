# Estado do projeto

*Atualizado em 2026-10-25. Manter curto; o detalhe está nos ficheiros ligados.*

## Fase atual
**2 · Painel, estatísticas e histórico:** por planear ([`planning/fase-2.md`](planning/fase-2.md)).

## Feito
- **Fase 0 · Fundações:** concluída e publicada ([`planning/fase-0.md`](planning/fase-0.md)).
- **Fase 1A · Lista e offline:** concluída e publicada ([`planning/fase-1a.md`](planning/fase-1a.md)).
- **Fase 1B · Importar e exportar:** concluída e publicada (portão a 2026-10-25; [`planning/fase-1b.md`](planning/fase-1b.md)). No portão, a cópia JSON recusava compras com origem `lista`; corrigido com teste.
- **Regras e documentação:** regras unificadas em `AGENTS.md` e documentação em `docs/` (2026-10-21).
- **Repositório público:** entram `.claude/settings.json` e `AGENTS.md`; ficam só locais `.claude/skills/`, `.codex/` e `.vscode/`.

## Ecrãs
- Feitos: Entrada, Lista do mês, Concluir compra, Artigos, categorias e lojas, Importar e exportar, Definições.
- Em breve: Painel e estatísticas, Histórico.

## Em curso
- **Comparação de preços · P0 (EAN e fonte do preço):** código e testes feitos; falta aplicar `20261025000000_p0_ean.sql` no SQL Editor e o portão ([`comparacao-precos/P0-modelo-dados.md`](comparacao-precos/P0-modelo-dados.md)).

## Próximo
1. Portão do P0.
2. Planear e aprovar a Fase 2 ([`planning/fase-2.md`](planning/fase-2.md)).

## Pendentes sem fase
- Ligar a "Leaked Password Protection" no Supabase (Authentication → Policies). É o único aviso que os advisors ainda dão.
- Fazer uma cópia JSON mensal para `dados-privados/`.

## Decisões em aberto
- Plugins Flutter do Claude Code: reduzir os três (`flutter`, `dart-flutter`, `flutter-skills`) a quais? O `dart-flutter` traz o MCP Dart.

## Referências
- Arquitetura: [`architecture/visao-geral.md`](architecture/visao-geral.md), [`architecture/mapa.md`](architecture/mapa.md), [`architecture/sincronizacao.md`](architecture/sincronizacao.md)
- Decisões: [`decisions/`](decisions/)
- Portões: [`testing/portoes.md`](testing/portoes.md)
- Fora do âmbito: [`planning/notas.md`](planning/notas.md)
