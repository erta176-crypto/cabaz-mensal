-- Cabaz Mensal · Fase 14 · artigos de uma barra do Painel (só leitura; não altera dados)

-- ---------------------------------------------------------------------------
-- RPC artigos_do_painel: os artigos que dão o valor de uma barra do painel,
-- com as mesmas regras da RPC painel (fase2):
--   - compras do utilizador entre p_de e p_ate, opcionalmente de uma loja;
--   - linhas somadas por pago_cent; categoria pelo artigo da linha.
-- Filtro de categoria: p_categorias (lista de ids) e/ou p_sem_categoria
-- (linhas sem categoria, incluindo as sem artigo). Sem nenhum dos dois, todas
-- as linhas (vista por loja).
-- A soma bate sempre com a barra (docs/planning/fase-14.md, D3):
--   artigos + sem_artigo_cent + diferenca_cent
--   = barra da loja (sum total_cent) ou da categoria (sum pago_cent).
-- Na Fase 15 (compras eliminadas) esta função muda junto com a painel.
-- ---------------------------------------------------------------------------
create or replace function public.artigos_do_painel(
  p_de date,
  p_ate date,
  p_loja uuid default null,
  p_categorias uuid[] default null,
  p_sem_categoria boolean default false
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with c as (
    select id, total_cent
    from public.compras
    where user_id = auth.uid()
      and data between p_de and p_ate
      and (p_loja is null or loja_id = p_loja)
  ),
  l as (
    select lc.compra_id, lc.artigo_id, lc.pago_cent, lc.quantidade, lc.peso_g,
           a.categoria_id
    from public.linhas_compra lc
    join c on c.id = lc.compra_id
    left join public.artigos a on a.id = lc.artigo_id
  ),
  todas as (
    select p_categorias is null and not p_sem_categoria as sim
  ),
  f as (
    select l.*
    from l, todas
    where todas.sim
       or l.categoria_id = any(p_categorias)
       or (p_sem_categoria and l.categoria_id is null)
  )
  select jsonb_build_object(
    'artigos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'artigo_id', artigo_id,
               'total_cent', t,
               'quantidade', q,
               'peso_g', g,
               'n_compras', n)
             order by t desc, artigo_id)
      from (select artigo_id,
                   sum(pago_cent) as t,
                   coalesce(sum(quantidade), 0) as q,
                   coalesce(sum(peso_g), 0) as g,
                   count(distinct compra_id) as n
            from f
            where artigo_id is not null
            group by artigo_id) x), '[]'::jsonb),
    'sem_artigo_cent',
      (select coalesce(sum(pago_cent), 0) from f where artigo_id is null),
    -- Só na vista por loja: compras sem linhas ou cujas linhas não somam o total.
    'diferenca_cent', case when (select sim from todas) then
        (select coalesce(sum(total_cent), 0) from c)
        - (select coalesce(sum(pago_cent), 0) from l)
      else 0 end
  );
$$;

revoke execute on function public.artigos_do_painel(date, date, uuid, uuid[], boolean) from public, anon;
grant execute on function public.artigos_do_painel(date, date, uuid, uuid[], boolean) to authenticated;
