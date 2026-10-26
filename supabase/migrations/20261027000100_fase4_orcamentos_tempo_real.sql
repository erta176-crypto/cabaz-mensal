-- Cabaz Mensal · Fase 4 · orçamentos em tempo real (como as outras tabelas
-- sincronizadas). Sem isto, as alterações chegam na mesma pela sincronização
-- periódica (30 s), só que não na hora.
alter publication supabase_realtime add table public.orcamentos;
