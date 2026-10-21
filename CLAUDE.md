@AGENTS.md

# Específico do Claude Code

- **Graphify:** o hook `Stop` em `.claude/settings.json` corre `graphify update . --force` quando `lib/`, `test/` ou `supabase/migrations/` mudaram desde a última atualização (ou quando o grafo ainda não existe). No fim da tarefa, confirmar que correu.
- **Modelos:** Opus planeia e revê; Sonnet executa o plano. Não reabrir decisões já tomadas no plano da fase.
- **Contexto:** `/clear` depois de cada portão.
- **Skills:** carregar só a que a tarefa precisa: `flutter:*` (arquitetura, Riverpod, drift, testes, async, acessibilidade, i18n), `dart-flutter:*` (análise estática, testes, conflitos de pacotes), `flutter-skills:*` (gerar ecrãs, providers, modelos, testes).
- **MCP Supabase:** esquema (`list_tables`), SQL de verificação, logs e advisors (`get_advisors` depois de cada migração). O `apply_migration` é recusado pelas permissões: as migrações são aplicadas pelo utilizador no SQL Editor.
- **MCP Dart/Flutter** (quando ligado): análise, erros em tempo de execução, hot reload.
