# Estado do projeto

*Atualizado em 2026-10-30. Manter curto; o detalhe está nos ficheiros ligados.*

## Fase atual
**8 · Entrada (mostrar palavra-passe, bloqueio com biometria):** plano aprovado a 2026-10-30 ([`planning/fase-8.md`](planning/fase-8.md)); T1 a T5 feitas e verificadas no telemóvel (decisão 0013). Falta o portão: ver na web e o utilizador confirmar; depois o push.

**7 · Talões por fotografia (OCR):** plano aprovado a 2026-10-28 ([`planning/fase-7.md`](planning/fase-7.md)); T1 a T5 feitas; T6 em curso: APK release instalado e a ler fotografias (regras do R8, decisão 0012), diálogos corrigidos para o telemóvel deitado; E.Leclerc em papel lido (leitor tolerante ao OCR); Pingo Doce e Lidl em papel lidos (2026-10-31; um algarismo estragado pelo OCR corrige-se na pré-visualização); falta só uma fotografia deitada (as quatro lojas, câmara e galeria só no Android, correção na pré-visualização; 3 fotos de exemplo em `dados-privados/talões/fotos/`).

## Feito
- **Fase 6 · Tema azul:** concluída e publicada (portão a 2026-10-28; [`planning/fase-6.md`](planning/fase-6.md)). Paleta azul e `CoresCabaz` (decisão 0011, substitui a 0008), cabeçalho alto em gradiente com os filtros em pílulas e a pesquisa (D6, revoga a D4), gaveta e barra inferior, cartões e orçamento com verde/âmbar/vermelho e percentagem. No portão: o gradiente do cabeçalho tinha altura 0, as pílulas no escuro tinham pouco contraste e os cartões do Painel tinham alturas diferentes na mesma linha — corrigidos com testes.
- **Fase 0 · Fundações:** concluída e publicada ([`planning/fase-0.md`](planning/fase-0.md)).
- **Fase 1A · Lista e offline:** concluída e publicada ([`planning/fase-1a.md`](planning/fase-1a.md)).
- **Comparação de preços · P0 · EAN e fonte do preço:** concluído (portão a 2026-10-25; [`comparacao-precos/P0-modelo-dados.md`](comparacao-precos/P0-modelo-dados.md)). No portão: GTIN-14 com 0 à frente passa a EAN-13, código repetido é recusado e a pesquisa de Artigos procura também pelo código.
- **Fase 5 · Talões em PDF:** concluída e publicada (portão a 2026-10-28; [`planning/fase-5.md`](planning/fase-5.md)). Pingo Doce, Lidl e E.Leclerc em Importar e exportar (vários PDFs, pré-visualização por talão, ligar linhas a artigos, categoria sugerida, aliases); 91/91 talões reais leem certo. `excel` trocado por `excel_community` para permitir o `pdfrx` (decisão 0010). No portão: os aliases não eram usados na importação (erro anterior) — corrigido.
- **Fase 4 · Orçamento mensal:** concluída e publicada (portão a 2026-10-27; [`planning/fase-4.md`](planning/fase-4.md)). Orçamento por mês (total e categorias, cópia do mês anterior), cartão no Painel, linha no rodapé da Lista, sincronizado (decisão 0009). No portão: correções do telemóvel deitado (menu fixo, filtros que rolam com pouca altura, duas colunas pela largura disponível) e Painel em primeiro no menu.
- **Fase 3 · Tema:** concluída e publicada (portão a 2026-10-26; [`planning/fase-3.md`](planning/fase-3.md)). Paleta violeta/azul/castanho claro (decisão 0008), tema Sistema/Claro/Escuro guardado no aparelho, botão sol/lua no menu lateral.
- **Fase 2 · Painel, estatísticas e histórico:** concluída e publicada (portão a 2026-10-26; [`planning/fase-2.md`](planning/fase-2.md)). No portão: limite de 10 s por pedido (no Android, sem rede, o pedido ficava preso), cartões do Painel com largura igual, eixo do gráfico do preço sem rótulos soltos. O tema escuro não foi verificado (a app não tem opção de tema; segue o sistema).
- **Fase 1B · Importar e exportar:** concluída e publicada (portão a 2026-10-25; [`planning/fase-1b.md`](planning/fase-1b.md)). No portão, a cópia JSON recusava compras com origem `lista`; corrigido com teste.
- **Regras e documentação:** regras unificadas em `AGENTS.md` e documentação em `docs/` (2026-10-21).
- **Repositório público:** entram `.claude/settings.json` e `AGENTS.md`; ficam só locais `.claude/skills/`, `.codex/` e `.vscode/`.

## Ecrãs
- Tema azul com escolha Sistema/Claro/Escuro (Definições e botão sol/lua no menu lateral).
- Feitos: Entrada, Lista do mês, Concluir compra, Artigos, categorias e lojas, Importar e exportar, Definições, Painel e estatísticas, Histórico (com detalhe da compra), Ver artigo com evolução do preço.

## Próximo
Ao retomar:
1. **Portão da Fase 8:**
   - ver na web, com `flutter run -d chrome`, que o "mostrar palavra-passe" funciona e que não há interruptor de bloqueio;
   - correr a verificação;
   - o utilizador confirma o portão e só então se faz o push. Este push leva também os commits da Fase 7, que ainda não foram publicados.
2. **Fase 7, portão por fechar:** falta uma fotografia tirada com o telemóvel deitado (rotação EXIF); depois, o portão da Fase 7.
3. **Depois:** o P1 da comparação de preços (primeiro conector), ou um ponto de `notas.md`, por exemplo os diálogos da Fase 5 com o telemóvel deitado ou atualizar pacotes.

## Pendentes sem fase
- Ligar a "Leaked Password Protection" no Supabase (Authentication → Policies). É o único aviso que os advisors ainda dão.
- Fazer uma cópia JSON mensal para `dados-privados/`.
- Talões de exemplo (reais) em `dados-privados/talões/` (fora do git); os testes usam talões fictícios.

## Decisões em aberto
- Plugins Flutter do Claude Code: reduzir os três (`flutter`, `dart-flutter`, `flutter-skills`) a quais? O `dart-flutter` traz o MCP Dart.

## Referências
- Arquitetura: [`architecture/visao-geral.md`](architecture/visao-geral.md), [`architecture/mapa.md`](architecture/mapa.md), [`architecture/sincronizacao.md`](architecture/sincronizacao.md)
- Decisões: [`decisions/`](decisions/)
- Portões: [`testing/portoes.md`](testing/portoes.md)
- Fora do âmbito: [`planning/notas.md`](planning/notas.md)
