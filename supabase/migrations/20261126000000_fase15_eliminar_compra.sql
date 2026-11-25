-- Cabaz Mensal · Fase 15 · eliminar um talão (compra) no Histórico
-- docs/planning/fase-15.md (D1, D2). Numa só transação: ou fica tudo, ou nada.
--
-- compras.apagado_em: a compra foi eliminada (só pela app, com rede; "Anular"
-- volta a pôr null). As linhas seguem a compra: todas as leituras de linhas
-- passam pela compra. As funções e a vista abaixo são as mesmas da fase2,
-- fase1a e fase14, só com o filtro "apagado_em is null" a mais.
-- Sem índice novo (fase-15.md, D1).
--
-- Como desfazer: voltar a correr as definições de painel e historico_compras
-- (20261026000000_fase2.sql), de artigos_do_painel
-- (20261125000000_fase14_artigos_do_painel.sql) e da vista resumo_por_loja
-- (20261015120000_fase1a.sql). A coluna pode ficar (null não muda nada).

begin;

alter table public.compras add column apagado_em timestamptz;

-- ---------------------------------------------------------------------------
-- RPC painel (fase2) sem as compras eliminadas.
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
      and apagado_em is null
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

-- ---------------------------------------------------------------------------
-- RPC historico_compras (fase2) sem as compras eliminadas.
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
    and c.apagado_em is null
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

-- ---------------------------------------------------------------------------
-- RPC artigos_do_painel (fase14) sem as compras eliminadas.
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
      and apagado_em is null
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

-- ---------------------------------------------------------------------------
-- Vista resumo_por_loja (fase1a) sem as compras eliminadas. O filtro fica na
-- junção para as lojas sem compras continuarem a aparecer (com 0).
-- ---------------------------------------------------------------------------
create or replace view public.resumo_por_loja
with (security_invoker = true)
as
select
  l.id as loja_id,
  l.slug,
  l.nome,
  count(c.id)::integer as n_compras,
  coalesce(sum(c.total_cent), 0)::bigint as total_cent
from public.lojas l
left join public.compras c on c.loja_id = l.id and c.apagado_em is null
where l.apagado_em is null
group by l.id, l.slug, l.nome;

commit;
