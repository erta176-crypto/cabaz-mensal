# Fase 2 · Painel, estatísticas e histórico

**Estado:** por planear. O plano tem de ser aprovado antes de implementar.

## Âmbito previsto
- **Painel e estatísticas:** gastos por mês, loja e categoria, com gráficos.
- **Histórico:** lista de compras passadas, com detalhe e pesquisa.

## Notas para o plano
- Calcular os totais do painel no servidor, com uma RPC, em vez de puxar todas as linhas para o telemóvel.
- A tabela `registos_preco` já guarda o histórico de preços para os gráficos.

## A decidir no plano
- Biblioteca de gráficos: nenhuma consta da lista atual de pacotes. Confirmar no `pubspec.yaml`; se for preciso um pacote novo, comparar opções (licença, suporte web, tamanho) e decidir antes de o adicionar.

## Depois da Fase 2
- Importação de talões em PDF e por fotografia (ML Kit, só no Android).
- Avisos de preço.
- Orçamento mensal.
- Fora de âmbito: iOS.
