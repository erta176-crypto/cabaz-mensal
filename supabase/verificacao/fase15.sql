-- Cabaz Mensal · Fase 15 · verificação (só leitura; não altera dados)
-- Compara o que a app lê com uma contagem direta nas tabelas, só com as
-- compras não eliminadas (apagado_em is null):
--   - painel: total e n.º de compras ("este mês" e "tudo", sem e com loja);
--   - historico_compras: n.º e soma das compras, nos mesmos filtros;
--   - resumo_por_loja: n.º e total por loja.
-- A coluna "diferentes" tem de ser 0. A última linha diz quantas compras
-- estão eliminadas (0 logo depois da migração; 1 depois do portão).
-- Correr também fase14.sql (artigos_do_painel bate com o painel).
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
direto as (
  select f.periodo, f.loja,
         count(c.id) as n,
         coalesce(sum(c.total_cent), 0) as t
  from filtros f
  left join public.compras c
    on c.user_id = auth.uid()
   and c.apagado_em is null
   and c.data between f.de and f.ate
   and (f.loja is null or c.loja_id = f.loja)
  group by f.periodo, f.loja
),
pn as (
  select f.periodo, f.loja, public.painel(f.de, f.ate, f.loja) as j
  from filtros f
),
hist as (
  select f.periodo, f.loja,
         count(h.id) as n,
         coalesce(sum(h.total_cent), 0) as t
  from filtros f
  left join lateral public.historico_compras(f.de, f.ate, f.loja) h on true
  group by f.periodo, f.loja
),
resumo_direto as (
  select l.id as loja_id,
         count(c.id) as n,
         coalesce(sum(c.total_cent), 0) as t
  from public.lojas l
  left join public.compras c on c.loja_id = l.id and c.apagado_em is null
  where l.apagado_em is null and l.user_id = auth.uid()
  group by l.id
)
select 'painel' as leitura,
       count(*) as filtros,
       count(*) filter (
         where (pn.j->>'total_cent')::bigint <> d.t
            or (pn.j->>'n_compras')::bigint <> d.n
       ) as diferentes
from pn
join direto d on d.periodo = pn.periodo and d.loja is not distinct from pn.loja
union all
select 'historico_compras', count(*),
       count(*) filter (where h.t <> d.t or h.n <> d.n)
from hist h
join direto d on d.periodo = h.periodo and d.loja is not distinct from h.loja
union all
select 'resumo_por_loja', count(*),
       count(*) filter (where r.total_cent <> rd.t or r.n_compras <> rd.n)
from public.resumo_por_loja r
join resumo_direto rd on rd.loja_id = r.loja_id
union all
select 'compras eliminadas',
       (select count(*) from public.compras
        where user_id = auth.uid() and apagado_em is not null),
       null;

rollback;
