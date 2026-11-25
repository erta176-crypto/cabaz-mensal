-- Cabaz Mensal · Fase 14 · verificação (só leitura; não altera dados)
-- Para cada barra do painel ("este mês" e "tudo"; sem loja e com cada loja),
-- compara o valor da barra com a soma de artigos_do_painel no mesmo filtro:
-- lojas, categorias, "Sem categoria" e "Outras" (categorias fora das 8 maiores).
-- Devolve só contagens. A coluna "diferentes" tem de ser 0 em todas as linhas.
-- Corre com a sessão do utilizador das compras (um só utilizador).
begin;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select user_id from public.compras limit 1),
    'role', 'authenticated'
  )::text,
  true
);

with periodos(periodo, de, ate) as (
  values
    ('este mês',
     date_trunc('month', current_date)::date,
     (date_trunc('month', current_date) + interval '1 month - 1 day')::date),
    ('tudo', date '2000-01-01', current_date + 1)
),
filtros as (
  select p.periodo, p.de, p.ate, null::uuid as loja from periodos p
  union all
  select p.periodo, p.de, p.ate, l.id
  from periodos p, public.lojas l
  where l.user_id = auth.uid()
),
pn as (
  select f.*, public.painel(f.de, f.ate, f.loja) as j from filtros f
),
casos as (
  -- Barras "Por loja" (só no painel sem loja).
  select 'loja' as tipo, pn.periodo, (x->>'total_cent')::bigint as barra,
         public.artigos_do_painel(pn.de, pn.ate, (x->>'loja_id')::uuid, null, false) as d
  from pn, jsonb_array_elements(pn.j->'por_loja') x
  where pn.loja is null
  union all
  -- Barras "Por categoria" (com e sem loja), incluindo "Sem categoria".
  select case when x->>'categoria_id' is null then 'sem categoria' else 'categoria' end,
         pn.periodo, (x->>'total_cent')::bigint,
         public.artigos_do_painel(
           pn.de, pn.ate, pn.loja,
           case when x->>'categoria_id' is null then null
                else array[(x->>'categoria_id')::uuid] end,
           x->>'categoria_id' is null)
  from pn, jsonb_array_elements(pn.j->'por_categoria') x
  union all
  -- "Outras": as categorias depois das 8 maiores, numa só chamada.
  select 'outras', pn.periodo, o.barra,
         public.artigos_do_painel(pn.de, pn.ate, pn.loja, o.ids, o.tem_sem)
  from pn,
       lateral (
         select sum((v->>'total_cent')::bigint) as barra,
                array_agg((v->>'categoria_id')::uuid)
                  filter (where v->>'categoria_id' is not null) as ids,
                coalesce(bool_or(v->>'categoria_id' is null), false) as tem_sem
         from jsonb_array_elements(pn.j->'por_categoria') with ordinality y(v, i)
         where i > 8
       ) o
  where o.barra is not null
),
somas as (
  select tipo, periodo, barra,
         (select coalesce(sum((a->>'total_cent')::bigint), 0)
          from jsonb_array_elements(d->'artigos') a)
         + (d->>'sem_artigo_cent')::bigint
         + (d->>'diferenca_cent')::bigint as soma
  from casos
)
select tipo, periodo, count(*) as barras,
       count(*) filter (where barra <> soma) as diferentes
from somas
group by tipo, periodo
order by tipo, periodo;

rollback;
