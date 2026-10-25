-- Cabaz Mensal · Fase 2 · painel e histórico (só leitura; não altera dados)

-- ---------------------------------------------------------------------------
-- RPC painel: totais de um período, opcionalmente de uma loja.
-- Por categoria e por artigo soma as linhas (pago_cent); o total soma as compras.
-- ---------------------------------------------------------------------------
create or replace function public.painel(p_de date, p_ate date, p_loja uuid default null)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with c as (
    select id, loja_id, data, total_cent, poupanca_cent
    from public.compras
    where user_id = auth.uid()
      and data between p_de and p_ate
      and (p_loja is null or loja_id = p_loja)
  ),
  l as (
    select lc.artigo_id, lc.pago_cent, a.categoria_id
    from public.linhas_compra lc
    join c on c.id = lc.compra_id
    left join public.artigos a on a.id = lc.artigo_id
  )
  select jsonb_build_object(
    'total_cent', (select coalesce(sum(total_cent), 0) from c),
    'n_compras', (select count(*) from c),
    'poupanca_cent', (select coalesce(sum(poupanca_cent), 0) from c),
    'por_mes', coalesce((
      select jsonb_agg(jsonb_build_object('mes', to_char(m, 'YYYY-MM'), 'total_cent', t, 'n_compras', n) order by m)
      from (select date_trunc('month', data)::date as m, sum(total_cent) as t, count(*) as n
            from c group by 1) x), '[]'::jsonb),
    'por_loja', coalesce((
      select jsonb_agg(jsonb_build_object('loja_id', loja_id, 'total_cent', t, 'n_compras', n) order by t desc)
      from (select loja_id, sum(total_cent) as t, count(*) as n from c group by 1) x), '[]'::jsonb),
    'por_categoria', coalesce((
      select jsonb_agg(jsonb_build_object('categoria_id', categoria_id, 'total_cent', t) order by t desc)
      from (select categoria_id, sum(pago_cent) as t from l group by 1) x), '[]'::jsonb),
    'artigos', coalesce((
      select jsonb_agg(jsonb_build_object('artigo_id', artigo_id, 'total_cent', t, 'n_linhas', n) order by t desc)
      from (select artigo_id, sum(pago_cent) as t, count(*) as n
            from l where artigo_id is not null
            group by 1 order by 2 desc limit 10) x), '[]'::jsonb)
  );
$$;

revoke execute on function public.painel(date, date, uuid) from public, anon;
grant execute on function public.painel(date, date, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC historico_compras: compras de um período, opcionalmente de uma loja,
-- e só as que têm uma linha com um dos artigos ou com o texto no talão.
-- p_artigos vem da app (pesquisa sem acentos no catálogo local).
-- ---------------------------------------------------------------------------
create or replace function public.historico_compras(
  p_de date,
  p_ate date,
  p_loja uuid default null,
  p_artigos uuid[] default null,
  p_texto text default null
)
returns table (
  id uuid, loja_id uuid, data date, local text, total_cent integer,
  poupanca_cent integer, origem text, rever boolean, n_linhas integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.id, c.loja_id, c.data, c.local, c.total_cent, c.poupanca_cent, c.origem, c.rever,
         (select count(*)::integer from public.linhas_compra lc where lc.compra_id = c.id)
  from public.compras c
  where c.user_id = auth.uid()
    and c.data between p_de and p_ate
    and (p_loja is null or c.loja_id = p_loja)
    and (
      (p_artigos is null and p_texto is null)
      or exists (
        select 1 from public.linhas_compra lc
        where lc.compra_id = c.id
          and (lc.artigo_id = any (coalesce(p_artigos, '{}'))
               or (p_texto is not null and strpos(lower(coalesce(lc.texto_original, '')), lower(p_texto)) > 0))
      )
    )
  order by c.data desc, c.criado_em desc;
$$;

revoke execute on function public.historico_compras(date, date, uuid, uuid[], text) from public, anon;
grant execute on function public.historico_compras(date, date, uuid, uuid[], text) to authenticated;
