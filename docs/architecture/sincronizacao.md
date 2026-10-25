# Sincronização

A app funciona sem rede. Toda a escrita passa pela cache local (drift) e por uma fila; a fila é enviada ao Supabase quando há ligação.

## Escrita (`lib/data/sync/escrita.dart`)
- Grava na cache e põe a operação na fila `pendentes`.
- Criar envia a linha completa; editar envia só as colunas alteradas.

## Envio e receção (`lib/data/sync/sincronizador.dart`)
- Envio por ordem, com espera crescente entre tentativas.
- Receção por `atualizado_em`, com margem de 5 min.
- O cursor da receção nunca fica atrás de `agora()` do servidor menos a margem.

## Regras
- `itens_lista` e `aliases` sincronizam pela chave natural.
- Eliminar marca `apagado_em`. Voltar a criar algo apagado reativa a mesma linha (mesmo id), nunca cria uma linha nova.
- Índices únicos sempre completos.
- `preferencias.reiniciado_em` manda limpar a cache (`limparCache`: registos, cursores `cursor:%` e painéis guardados `painel:%`).
- Vence a última escrita a chegar ao servidor.

## Testes
`test/sync/`: servidor falso em memória e drift em memória.
